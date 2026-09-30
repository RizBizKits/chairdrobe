import SwiftUI

struct BookmarkListView: View {
    @Bindable var store: BookmarkStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(store.bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                        BookmarkRow(
                            bookmark: bookmark,
                            isFocused: store.focusedID == bookmark.id
                        )
                        .id(bookmark.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            store.open(bookmark)
                        }
                        .onTapGesture {
                            store.focusedID = bookmark.id
                        }
                        .contextMenu {
                            Button("Open") { store.open(bookmark) }
                            Button("Edit") { store.editingID = bookmark.id }
                            Divider()
                            Button("Delete", role: .destructive) { store.delete(id: bookmark.id) }
                        }

                        if index < store.bookmarks.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 1)
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            .onAppear {
                if store.focusedID == nil {
                    store.focusedID = store.bookmarks.first?.id
                }
            }
            .onChange(of: store.focusedID) { _, newValue in
                if let newValue {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }
}

struct BookmarkRow: View {
    let bookmark: Bookmark
    let isFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Capsule()
                .fill(isFocused ? Brand.neonGreen : Color.clear)
                .frame(width: 3, height: 34)

            FaviconView(urlString: bookmark.faviconURLString, host: bookmark.displayHost)

            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(.system(size: 15, weight: isFocused ? .bold : .semibold))
                    .foregroundStyle(Brand.textPrimary.opacity(isFocused ? 1 : 0.92))
                    .lineLimit(1)

                if !bookmark.descriptionText.isEmpty {
                    Text(bookmark.descriptionText)
                        .font(.system(size: 13))
                        .foregroundStyle(Brand.textSecondary.opacity(isFocused ? 1 : 0.88))
                        .lineLimit(2)
                }

                Text(bookmark.displayHost)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Brand.neonGreen.opacity(isFocused ? 1 : 0.85))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.trailing, 4)
    }
}

struct FaviconView: View {
    let urlString: String?
    let host: String

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var placeholder: some View {
        Text(String(host.prefix(1)).uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Brand.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
