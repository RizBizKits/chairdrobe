import SwiftUI

enum Brand {
    /// Flat brand blue from chairdrobe assets (#0010FB)
    static let blue = Color(red: 0 / 255, green: 16 / 255, blue: 251 / 255)
    static let neonGreen = Color(red: 17 / 255, green: 246 / 255, blue: 1 / 255)
    static let chairRed = Color(red: 0.95, green: 0.12, blue: 0.18)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.86)
    static let rowFill = Color.white.opacity(0.08)
    static let rowSelected = Color.white.opacity(0.14)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.35)

    static let popoverWidth: CGFloat = 360
    static let listPopoverHeight: CGFloat = 420
    static let editPopoverHeight: CGFloat = 360

    /// Brand empty (chair) — landscape-ish like the asset
    static let emptyPopoverWidth: CGFloat = 360
    static let emptyPopoverHeight: CGFloat = 248

    static let popoverHeight: CGFloat = listPopoverHeight
}

enum FeedbackMessage: Equatable {
    case saved
    case alreadyInPile
    case invalidURL
    case confirmDelete
    case removed
    case custom(String)

    var text: String {
        switch self {
        case .saved: return "Saved to your pile"
        case .alreadyInPile: return "Already in the pile"
        case .invalidURL: return "That doesn’t look like a valid link"
        case .confirmDelete: return "Press ⌫ again to delete · Esc to cancel"
        case .removed: return "Removed from your pile"
        case .custom(let s): return s
        }
    }

    /// One line, short enough to sit in the cover footer without growing it.
    var compactText: String {
        switch self {
        case .saved: return "Saved"
        case .alreadyInPile: return "Already in the pile"
        case .invalidURL: return "Not a valid link"
        case .confirmDelete: return "Press ⌫ again"
        case .removed: return "Removed"
        case .custom(let s): return s
        }
    }

    var isError: Bool {
        switch self {
        case .invalidURL, .confirmDelete: return true
        default: return false
        }
    }

    var showsUndo: Bool {
        if case .removed = self { return true }
        return false
    }
}
