import Foundation

enum CottageActionKind {
    case application
    case command
    case finderItem
    case systemSettingsItem

    var title: String {
        switch self {
        case .application:
            L10n.text("actionKind.application")
        case .command:
            L10n.text("actionKind.command")
        case .finderItem:
            L10n.text("actionKind.finderItem")
        case .systemSettingsItem:
            L10n.text("actionKind.systemSettingsItem")
        }
    }

    var symbolName: String {
        switch self {
        case .application:
            "app"
        case .command:
            "terminal"
        case .finderItem:
            "folder"
        case .systemSettingsItem:
            "gearshape"
        }
    }
}
