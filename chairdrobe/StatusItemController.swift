import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let store: BookmarkStore
    private let dropView: StatusItemDropView
    private var iconFlashWork: DispatchWorkItem?
    private var keyMonitor: Any?

    init(store: BookmarkStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let size = NSSize(width: 22, height: 22)
        dropView = StatusItemDropView(frame: NSRect(origin: .zero, size: size))
        super.init()

        configureIcon()
        dropView.onClick = { [weak self] in self?.togglePopover() }
        dropView.onDropStrings = { [weak self] strings in
            self?.handleDroppedStrings(strings)
        }

        statusItem.view = dropView

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: Brand.popoverWidth, height: Brand.popoverHeight)

        let root = BookmarkPopoverView(
            store: store,
            onQuit: { [weak self] in
                self?.popover.performClose(nil)
                NSApp.terminate(nil)
            },
            onPreferredSizeChange: { [weak self] size in
                guard let self else { return }
                // Avoid jitter from redundant contentSize writes.
                if self.popover.contentSize != size {
                    self.popover.contentSize = size
                }
            }
        )
        popover.contentViewController = KeyableHostingController(rootView: root)
    }

    private func configureIcon() {
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            dropView.icon = image
        } else {
            let fallback = NSImage(systemSymbolName: "link.circle", accessibilityDescription: "chairdrobe")
            fallback?.isTemplate = true
            dropView.icon = fallback
        }
        dropView.toolTip = "chairdrobe — drop a link to save it"
    }

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        NSApp.activate(ignoringOtherApps: true)
        let alreadyOpen = popover.isShown
        popover.show(relativeTo: dropView.bounds, of: dropView, preferredEdge: .minY)
        dropView.isHighlighted = true
        if !alreadyOpen {
            store.showingList = false
            store.editingID = nil
        }

        // Ensure the popover can receive keys (SwiftUI onKeyPress is flaky here).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            self.popover.contentViewController?.view.window?.makeFirstResponder(
                self.popover.contentViewController?.view
            )
            self.installKeyMonitor()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        dropView.isHighlighted = false
        removeKeyMonitor()
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            return self.handleKeyEvent(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    /// Returns true when the event was handled.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // While editing, let text fields own typing; still handle Esc.
        if store.editingID != nil {
            if event.keyCode == 53 { // escape
                store.editingID = nil
                return true
            }
            return false
        }

        // Undo works even after deleting the last item.
        if event.keyCode == 6, // Z
           store.canUndoDelete,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            store.undoLastDelete()
            return true
        }

        if !store.showingList {
            if event.keyCode == 36 || event.keyCode == 76, !store.bookmarks.isEmpty {
                store.openPile()
                return true
            }
            if event.keyCode == 53 {
                popover.performClose(nil)
                return true
            }
            return false
        }

        if store.bookmarks.isEmpty {
            store.showingList = false
            if event.keyCode == 53 {
                popover.performClose(nil)
                return true
            }
            return false
        }

        switch event.keyCode {
        case 126: // up arrow
            store.clearPendingDelete()
            moveFocus(by: -1)
            return true
        case 125: // down arrow
            store.clearPendingDelete()
            moveFocus(by: 1)
            return true
        case 36, 76: // return / keypad enter
            store.clearPendingDelete()
            openFocused()
            return true
        case 51, 117: // delete (backspace) / forward delete
            deleteFocused()
            return true
        case 14: // E
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
               let id = store.focusedID {
                store.clearPendingDelete()
                store.editingID = id
                return true
            }
            return false
        case 53: // escape
            if store.pendingDeleteID != nil {
                store.clearPendingDelete()
                store.feedback = nil
                return true
            }
            store.showCover()
            return true
        default:
            return false
        }
    }

    private func moveFocus(by delta: Int) {
        let ids = store.bookmarks.map(\.id)
        guard !ids.isEmpty else { return }
        let current = store.focusedID.flatMap { ids.firstIndex(of: $0) } ?? 0
        let next = min(max(current + delta, 0), ids.count - 1)
        store.focusedID = ids[next]
    }

    private func openFocused() {
        guard let id = store.focusedID,
              let bookmark = store.bookmarks.first(where: { $0.id == id })
        else { return }
        store.open(bookmark)
    }

    private func deleteFocused() {
        guard let id = store.focusedID else { return }
        store.requestDelete(id: id)
    }

    private func handleDroppedStrings(_ strings: [String]) {
        let candidates = strings.flatMap { extractURLs(from: $0) }
        guard let first = candidates.first else {
            store.showFeedback(.invalidURL)
            flashIcon(title: "Invalid")
            showPopover()
            return
        }

        let result = store.addURL(from: first)
        switch result {
        case .added:
            flashIcon(title: "Saved")
        case .duplicate:
            flashIcon(title: "In pile")
        case .invalid:
            flashIcon(title: "Invalid")
        }
        showPopover()
    }

    private func extractURLs(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if URLNormalizer.normalizedHTTPURL(from: trimmed) != nil {
            return [trimmed]
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return detector.matches(in: trimmed, range: range).compactMap { match in
            guard let range = Range(match.range, in: trimmed) else { return nil }
            return String(trimmed[range])
        }
    }

    private func flashIcon(title: String) {
        iconFlashWork?.cancel()
        dropView.flashTitle = title
        let work = DispatchWorkItem { [weak self] in
            self?.dropView.flashTitle = nil
        }
        iconFlashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
}

/// Hosting controller that can become first responder so the popover accepts keys.
final class KeyableHostingController<Content: View>: NSHostingController<Content> {
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
    }

    override var acceptsFirstResponder: Bool { true }
}

final class StatusItemDropView: NSView {
    var onClick: (() -> Void)?
    var onDropStrings: (([String]) -> Void)?
    var icon: NSImage? { didSet { needsDisplay = true } }
    var flashTitle: String? { didSet { needsDisplay = true } }
    var isHighlighted = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([
            .URL,
            .fileURL,
            .string,
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("public.utf8-plain-text")
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isHighlighted {
            NSColor.controlAccentColor.withAlphaComponent(0.35).setFill()
            dirtyRect.insetBy(dx: 1, dy: 1).fill()
        }

        if let flashTitle {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
            let size = (flashTitle as NSString).size(withAttributes: attrs)
            let origin = NSPoint(
                x: (bounds.width - size.width) / 2,
                y: (bounds.height - size.height) / 2
            )
            (flashTitle as NSString).draw(at: origin, withAttributes: attrs)
            return
        }

        guard let icon else { return }
        let iconSize = NSSize(width: 18, height: 18)
        let origin = NSPoint(
            x: (bounds.width - iconSize.width) / 2,
            y: (bounds.height - iconSize.height) / 2
        )
        icon.draw(
            in: NSRect(origin: origin, size: iconSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isHighlighted = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        let pb = sender.draggingPasteboard
        var strings: [String] = []

        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            strings.append(contentsOf: urls.map(\.absoluteString))
        }
        if let str = pb.string(forType: .string) {
            strings.append(str)
        }
        if let str = pb.string(forType: NSPasteboard.PasteboardType("public.url")) {
            strings.append(str)
        }

        guard !strings.isEmpty else { return false }
        onDropStrings?(strings)
        return true
    }
}
