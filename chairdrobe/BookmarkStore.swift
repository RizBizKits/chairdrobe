import AppKit
import Foundation
import Observation

@Observable
final class BookmarkStore {
    private(set) var bookmarks: [Bookmark] = []
    var feedback: FeedbackMessage?
    var focusedID: UUID?
    var editingID: UUID?
    /// Chair cover is the front door. The list opens from the link count.
    var showingList = false
    /// First ⌫ arms deletion; second ⌫ on the same row confirms.
    var pendingDeleteID: UUID?

    private let fileURL: URL
    private let metadata: MetadataService
    private var feedbackClearTask: Task<Void, Never>?
    private var fetchTasks: [UUID: Task<Void, Never>] = [:]
    private var lastRemoved: (bookmark: Bookmark, index: Int)?

    init(
        fileURL: URL = BookmarkStore.defaultFileURL(),
        metadata: MetadataService = MetadataService()
    ) {
        self.fileURL = fileURL
        self.metadata = metadata
        load()
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("chairdrobe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("bookmarks.json")
    }

    @discardableResult
    func addURL(from raw: String) -> AddResult {
        clearPendingDelete()
        guard let normalized = URLNormalizer.normalizedHTTPURL(from: raw) else {
            showFeedback(.invalidURL)
            return .invalid
        }

        let key = normalized.lowercased()
        if let existing = bookmarks.first(where: { URLNormalizer.dedupeKey(for: $0.urlString) == key }) {
            focusedID = existing.id
            showFeedback(.alreadyInPile)
            return .duplicate(existing.id)
        }

        let bookmark = Bookmark(urlString: normalized)
        bookmarks.insert(bookmark, at: 0)
        focusedID = bookmark.id
        persist()
        showFeedback(.saved)
        refreshMetadata(for: bookmark.id)
        return .added(bookmark.id)
    }

    func update(_ bookmark: Bookmark, refreshMetadataIfURLChanged: Bool) {
        clearPendingDelete()
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        let oldURL = bookmarks[index].urlString
        var updated = bookmark
        updated.updatedAt = Date()

        guard let normalized = URLNormalizer.normalizedHTTPURL(from: updated.urlString) else {
            showFeedback(.invalidURL)
            return
        }
        updated.urlString = normalized

        let key = normalized.lowercased()
        if bookmarks.contains(where: { $0.id != updated.id && URLNormalizer.dedupeKey(for: $0.urlString) == key }) {
            showFeedback(.custom("That link is already in the pile"))
            return
        }

        if refreshMetadataIfURLChanged, oldURL.lowercased() != normalized.lowercased() {
            updated.title = updated.displayHost
            updated.descriptionText = ""
            updated.faviconURLString = nil
            bookmarks[index] = updated
            persist()
            refreshMetadata(for: updated.id)
        } else {
            bookmarks[index] = updated
            persist()
        }
        editingID = nil
    }

    /// Keyboard delete: arm on first press, remove on second press of the same row.
    func requestDelete(id: UUID) {
        if pendingDeleteID == id {
            performDelete(id: id)
            return
        }
        pendingDeleteID = id
        focusedID = id
        showFeedback(.confirmDelete, durationNanoseconds: 4_000_000_000)
    }

    /// Context menu / explicit Delete button: remove immediately, offer Undo.
    func delete(id: UUID) {
        performDelete(id: id)
    }

    func undoLastDelete() {
        guard let removed = lastRemoved else { return }
        let index = min(removed.index, bookmarks.count)
        bookmarks.insert(removed.bookmark, at: index)
        focusedID = removed.bookmark.id
        lastRemoved = nil
        pendingDeleteID = nil
        persist()
        showFeedback(.custom("Restored"))
    }

    var canUndoDelete: Bool { lastRemoved != nil }

    func clearPendingDelete() {
        if pendingDeleteID != nil {
            pendingDeleteID = nil
            if case .confirmDelete = feedback {
                feedback = nil
            }
        }
    }

    func openPile() {
        guard !bookmarks.isEmpty else { return }
        if focusedID == nil {
            focusedID = bookmarks.first?.id
        }
        showingList = true
    }

    func showCover() {
        editingID = nil
        clearPendingDelete()
        showingList = false
    }

    func open(_ bookmark: Bookmark) {
        clearPendingDelete()
        guard let url = bookmark.url else {
            showFeedback(.invalidURL)
            return
        }
        NSWorkspace.shared.open(url)
    }

    func showFeedback(_ message: FeedbackMessage, durationNanoseconds: UInt64 = 2_400_000_000) {
        feedback = message
        feedbackClearTask?.cancel()
        feedbackClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: durationNanoseconds)
            if !Task.isCancelled, feedback == message {
                feedback = nil
                if case .confirmDelete = message {
                    pendingDeleteID = nil
                }
                if case .removed = message {
                    lastRemoved = nil
                }
            }
        }
    }

    private func performDelete(id: UUID) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        fetchTasks[id]?.cancel()
        fetchTasks[id] = nil
        let removed = bookmarks.remove(at: index)
        lastRemoved = (removed, index)
        pendingDeleteID = nil
        if focusedID == id { focusedID = bookmarks.first?.id }
        if editingID == id { editingID = nil }
        persist()

        // Last item → chair cover, no "Removed" toast.
        if bookmarks.isEmpty {
            feedback = nil
            lastRemoved = nil
            showingList = false
            editingID = nil
            return
        }

        showFeedback(.removed, durationNanoseconds: 3_000_000_000)
    }

    private func refreshMetadata(for id: UUID) {
        fetchTasks[id]?.cancel()
        guard let bookmark = bookmarks.first(where: { $0.id == id }),
              let url = bookmark.url
        else { return }

        fetchTasks[id] = Task { @MainActor in
            let result = await metadata.fetch(for: url)
            guard !Task.isCancelled,
                  let index = bookmarks.firstIndex(where: { $0.id == id })
            else { return }

            if let title = result.title, !title.isEmpty {
                bookmarks[index].title = title
            }
            if let description = result.description, !description.isEmpty {
                bookmarks[index].descriptionText = description
            }
            if let favicon = result.faviconURL?.absoluteString {
                bookmarks[index].faviconURLString = favicon
            }
            bookmarks[index].updatedAt = Date()
            persist()
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            bookmarks = try JSONDecoder().decode([Bookmark].self, from: data)
        } catch {
            bookmarks = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            showFeedback(.custom("Couldn’t save your pile to disk"))
        }
    }

    enum AddResult {
        case added(UUID)
        case duplicate(UUID)
        case invalid
    }
}
