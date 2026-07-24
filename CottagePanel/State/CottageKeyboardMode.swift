import AppKit
import Foundation

enum CottageKeyboardContext: String, Codable, CaseIterable {
    case search
    case list
    case preview
    case footer
    case actionMenu
}

enum CottageKeyboardNavigationScheme: String, Codable, CaseIterable, Identifiable {
    case arrows
    case wasd
    case hjkl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .arrows:
            return L10n.text("keyboard.scheme.arrows")
        case .wasd:
            return L10n.text("keyboard.scheme.wasd")
        case .hjkl:
            return L10n.text("keyboard.scheme.hjkl")
        }
    }
}

enum CottagePreviewScrollScheme: String, Codable, CaseIterable, Identifiable {
    case both
    case letterKeys = "jk"
    case pageKeys = "page"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .both:
            return L10n.text("keyboard.preview.both")
        case .letterKeys:
            return L10n.text("keyboard.preview.jk")
        case .pageKeys:
            return L10n.text("keyboard.preview.page")
        }
    }
}

enum CottageKeyboardDirection {
    case moveUp
    case moveDown
    case moveLeft
    case moveRight
}

enum CottagePreviewScrollCommand {
    case scrollUp
    case scrollDown
}

enum CottageMenuKeyboardCommand {
    case moveUp
    case moveDown
    case enter
    case moveLeft
    case moveRight
    case backspace
    case escape
}

extension Notification.Name {
    static let cottageMenuKeyboardCommand = Notification.Name("cottageMenuKeyboardCommand")
    static let cottagePreviewScrollCommand = Notification.Name("cottagePreviewScrollCommand")
}

extension Notification {
    var cottageMenuCommand: CottageMenuKeyboardCommand? {
        object as? CottageMenuKeyboardCommand
    }

    var cottagePreviewCommand: CottagePreviewScrollCommand? {
        object as? CottagePreviewScrollCommand
    }
}
