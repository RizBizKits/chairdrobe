import AppKit
import SwiftUI

struct BookmarkPopoverView: View {
    @Bindable var store: BookmarkStore
    var onQuit: () -> Void
    var onPreferredSizeChange: (CGSize) -> Void = { _ in }

    private var preferredSize: CGSize {
        if store.showingList, store.editingID != nil {
            return CGSize(width: Brand.popoverWidth, height: Brand.editPopoverHeight)
        }
        if store.showingList {
            return CGSize(width: Brand.popoverWidth, height: Brand.listPopoverHeight)
        }
        return CGSize(width: Brand.emptyPopoverWidth, height: Brand.emptyPopoverHeight)
    }

    var body: some View {
        Group {
            if store.showingList {
                populatedBody
            } else {
                ChairCoverView(
                    count: store.bookmarks.count,
                    feedback: store.feedback,
                    onOpenPile: { store.openPile() },
                    onQuit: onQuit
                )
            }
        }
        .frame(width: preferredSize.width, height: preferredSize.height)
        .preferredColorScheme(.dark)
        .onAppear { onPreferredSizeChange(preferredSize) }
        .onChange(of: store.bookmarks.count) { _, _ in onPreferredSizeChange(preferredSize) }
        .onChange(of: store.editingID) { _, _ in onPreferredSizeChange(preferredSize) }
        .onChange(of: store.showingList) { _, _ in onPreferredSizeChange(preferredSize) }
    }

    private var populatedBody: some View {
        ZStack {
            Brand.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Group {
                    if let editingID = store.editingID,
                       let bookmark = store.bookmarks.first(where: { $0.id == editingID }) {
                        EditBookmarkView(
                            bookmark: bookmark,
                            onSave: { updated in
                                store.update(updated, refreshMetadataIfURLChanged: true)
                            },
                            onCancel: { store.editingID = nil },
                            onDelete: {
                                store.delete(id: bookmark.id)
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    } else {
                        BookmarkListView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                footer
            }
        }
    }

    private var header: some View {
        Image("LogoType")
            .resizable()
            .scaledToFit()
            .frame(height: 38)
            .accessibilityLabel("chairdrobe")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Back") { store.showCover() }
                .buttonStyle(.plain)
                .foregroundStyle(Brand.textSecondary)
                .font(.system(size: 12, weight: .medium))

            Button("Quit") { onQuit() }
                .buttonStyle(.plain)
                .foregroundStyle(Brand.textSecondary)
                .font(.system(size: 12, weight: .medium))

            if store.editingID == nil, store.focusedID != nil, store.feedback == nil {
                Button("Edit") {
                    store.editingID = store.focusedID
                }
                .buttonStyle(.plain)
                .foregroundStyle(Brand.neonGreen)
                .font(.system(size: 12, weight: .semibold))
            }

            Spacer(minLength: 8)

            footerStatus
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 40)
        .background(Color.black.opacity(0.12))
    }

    @ViewBuilder
    private var footerStatus: some View {
        if let feedback = store.feedback {
            HStack(spacing: 10) {
                Text(feedback.text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(feedback.isError ? Brand.danger : Brand.neonGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if feedback.showsUndo, store.canUndoDelete {
                    Button("Undo") { store.undoLastDelete() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Brand.neonGreen)
                }
            }
        } else if store.editingID == nil {
            Text("↑↓ · ⏎ open · E edit · ⌫⌫ delete")
                .font(.system(size: 11))
                .foregroundStyle(Brand.textSecondary.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

struct ChairCoverView: View {
    var count: Int
    var feedback: FeedbackMessage?
    var onOpenPile: () -> Void
    var onQuit: () -> Void

    private var countLabel: String {
        count == 1 ? "1 link" : "\(count) links"
    }

    private var feedbackColor: Color {
        guard let feedback else { return Brand.textSecondary }
        return feedback.isError ? Brand.danger : Brand.neonGreen
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Brand.blue

                GeometryReader { geo in
                    Image("EmptyChair")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .accessibilityHidden(true)

                Image("LogoType")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 42)
                    .accessibilityLabel("chairdrobe")
                    .padding(.leading, 12)
                    .padding(.top, 10)
                    .shadow(color: Brand.blue.opacity(0.9), radius: 8, x: 0, y: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                if count > 0 { onOpenPile() }
            }
            .onHover { inside in
                guard count > 0 else { return }
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(count > 0 ? "your pile of" : "your pile of links")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Brand.textPrimary)

                        if count > 0 {
                            Button(countLabel, action: onOpenPile)
                                .buttonStyle(.plain)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 1)
                                .background(Brand.neonGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .accessibilityLabel("Open \(countLabel)")
                        }
                    }

                    if count == 0 {
                        Text(feedback?.compactText ?? "Drag a link onto the menu bar chair to start.")
                            .font(.system(size: 12, weight: feedback == nil ? .regular : .semibold))
                            .foregroundStyle(feedbackColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                if count > 0, let feedback {
                    Text(feedback.compactText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(feedbackColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Spacer(minLength: 8)
                }

                Button("Quit") { onQuit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Brand.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Brand.blue)
        }
        .background(Brand.blue)
        .clipped()
    }
}
