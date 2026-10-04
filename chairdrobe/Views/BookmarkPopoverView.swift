import AppKit
import SwiftUI

struct BookmarkPopoverView: View {
    @Bindable var store: BookmarkStore
    var onQuit: () -> Void
    var onPreferredSizeChange: (CGSize) -> Void = { _ in }

    // TEST ONLY — delete before pushing. Overrides the cover count without saving links.
    @State private var testCount: Int?

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
                    count: testCount ?? store.bookmarks.count,
                    feedback: store.feedback,
                    onOpenPile: { store.openPile() },
                    onQuit: onQuit
                )
                .overlay(alignment: .topTrailing) {
                    TestCountStepper(
                        count: testCount ?? store.bookmarks.count,
                        onStep: { delta in
                            let current = testCount ?? store.bookmarks.count
                            testCount = max(0, current + delta)
                        }
                    )
                }
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

                ShirtStackView(count: count)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)

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
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        if count > 0 {
                            Button(countLabel, action: onOpenPile)
                                .buttonStyle(.plain)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 1)
                                .background(Brand.neonGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .fixedSize()
                                .accessibilityLabel("Open \(countLabel)")
                        }
                    }
                    .layoutPriority(1)

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

/// Clothes dropped on the seat. Each link adds a garment that lies on the pile.
/// Color, side, and neck direction are scrambled per shirt so the stack does not tile.
private struct ShirtStackView: View {
    var count: Int

    private struct Garment {
        let asset: String
        let width: CGFloat
        let family: Int
    }

    private struct Placed {
        let asset: String
        let width: CGFloat
        let x: CGFloat
        let rise: CGFloat
        let degrees: Double
    }

    private static let garments: [Garment] = [
        Garment(asset: "RumpleWhite", width: 176, family: 0),
        Garment(asset: "RumpleGreen", width: 168, family: 1),
        Garment(asset: "RumpleBlack", width: 160, family: 2),
        Garment(asset: "RumpleWad", width: 150, family: 0),
        Garment(asset: "RumpleWhiteB", width: 158, family: 0),
        Garment(asset: "RumpleGreenB", width: 146, family: 1),
        Garment(asset: "RumpleBlackB", width: 154, family: 2),
        Garment(asset: "RumpleWadB", width: 142, family: 0),
        Garment(asset: "RumpleYellow", width: 176, family: 3),
        Garment(asset: "RumpleYellowB", width: 150, family: 3),
    ]

    private var shown: Int { max(count, 0) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<shown, id: \.self) { index in
                let placed = Self.placed(at: index)
                ZStack(alignment: .bottom) {
                    shirt(placed)
                        .colorMultiply(.black)
                        .offset(x: placed.x, y: -placed.rise + 6)
                    shirt(placed)
                        .offset(x: placed.x, y: -placed.rise)
                }
            }
        }
        .accessibilityLabel("\(shown) pieces of clothing on the chair")
    }

    private func shirt(_ placed: Placed) -> some View {
        Image(placed.asset)
            .resizable()
            .scaledToFit()
            .frame(width: placed.width * 1.3)
            .rotationEffect(.degrees(placed.degrees))
    }

    /// Stable for a given shirt index. Early shirts spread across the seat.
    /// Later ones tuck toward the middle and rise slowly, so the pile stays a hill.
    private static func placed(at index: Int) -> Placed {
        var previousFamily = -1
        var pick = 0
        for step in 0...index {
            pick = mix(step, 1) % garments.count
            var tries = 0
            while garments[pick].family == previousFamily && tries < garments.count {
                pick = (pick + 1) % garments.count
                tries += 1
            }
            if step == index { break }
            previousFamily = garments[pick].family
        }
        let garment = garments[pick]
        let spread = 52 / (1 + 0.14 * CGFloat(index))
        let side: CGFloat = mix(index, 4).isMultiple(of: 2) ? -1 : 1
        let jitter = CGFloat(mix(index, 6) % 15) - 7
        let x = index == 0 ? jitter * 0.35 : side * spread + jitter
        let rise = 7.5 * sqrt(CGFloat(index))
        let degrees = mix(index, 5).isMultiple(of: 2) ? 0.0 : 180.0
        return Placed(asset: garment.asset, width: garment.width, x: x, rise: rise, degrees: degrees)
    }

    private static func mix(_ index: Int, _ salt: Int) -> Int {
        var n = UInt32(bitPattern: Int32(truncatingIfNeeded: index &* 2_246_822_519 &+ salt &* 3_266_489_917 &+ 1))
        n ^= n >> 16
        n &*= 0x7feb352d
        n ^= n >> 15
        n &*= 0x846ca68b
        n ^= n >> 16
        return Int(n)
    }
}

/// TEST ONLY — delete before pushing. Steps the cover count without saving links.
private struct TestCountStepper: View {
    var count: Int
    var onStep: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            stepButton("−", delta: -1)
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Brand.textPrimary)
                .frame(minWidth: 18)
            stepButton("+", delta: 1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Brand.blue)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Brand.neonGreen, lineWidth: 1)
        }
        .padding(8)
        .accessibilityLabel("Test link count")
    }

    private func stepButton(_ title: String, delta: Int) -> some View {
        Button(title) { onStep(delta) }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.black)
            .frame(width: 18, height: 18)
            .background(Brand.neonGreen)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
