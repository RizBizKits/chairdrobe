import SwiftUI

struct EditBookmarkView: View {
    @State private var title: String
    @State private var urlString: String
    @State private var error: String?

    let onSave: (Bookmark) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    private let original: Bookmark

    init(
        bookmark: Bookmark,
        onSave: @escaping (Bookmark) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.original = bookmark
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        _title = State(initialValue: bookmark.title)
        _urlString = State(initialValue: bookmark.urlString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit bookmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Brand.textPrimary)

            field(label: "Title", text: $title)
            field(label: "URL", text: $urlString)

            if let error {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Brand.danger)
            }

            HStack(spacing: 8) {
                Button("Save") { save() }
                    .buttonStyle(BrandPrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])

                Button("Cancel") { onCancel() }
                    .buttonStyle(BrandGhostButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Delete") { onDelete() }
                    .buttonStyle(BrandGhostButtonStyle(destructive: true))
            }

            Text("Changing the URL refreshes title, description, and favicon.")
                .font(.system(size: 10))
                .foregroundStyle(Brand.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func field(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Brand.textSecondary)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(Brand.textPrimary)
                .font(.system(size: 12))
        }
    }

    private func save() {
        guard URLNormalizer.normalizedHTTPURL(from: urlString) != nil else {
            error = "That doesn’t look like a valid link."
            return
        }
        var updated = original
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? original.displayHost
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(updated)
    }
}

struct BrandPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Brand.neonGreen.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct BrandGhostButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(destructive ? Brand.danger : Brand.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
