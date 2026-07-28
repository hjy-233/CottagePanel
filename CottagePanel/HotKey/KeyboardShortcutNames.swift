// 集中声明 Cottage 可配置快捷键的持久化名称
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self(
        "togglePanel",
        default: .init(.space, modifiers: [.command, .shift])
    )
    static let showActionMenu = Self(
        "showActionMenu",
        default: .init(.k, modifiers: [.command])
    )
    static let copySelectedResult = Self(
        "copySelectedResult",
        default: .init(.c, modifiers: [.command, .shift])
    )
    static let focusPreview = Self(
        "focusPreview",
        default: .init(.return, modifiers: [.option])
    )
    static let focusSearch = Self(
        "focusSearch",
        default: .init(.slash, modifiers: [])
    )
    static let showSelectionActions = Self(
        "showSelectionActions",
        default: .init(.slash, modifiers: [.shift])
    )
    static let showNumberedActions = Self(
        "showNumberedActions",
        default: .init(.slash, modifiers: [.command, .shift])
    )
    static let favoriteAction = Self(
        "favoriteAction",
        default: .init(.s, modifiers: [.command])
    )
    static let revealInFinder = Self(
        "revealInFinder",
        default: .init(.f, modifiers: [.command])
    )
    static let copyName = Self(
        "copyName",
        default: .init(.c, modifiers: [.command])
    )
    static let copyPath = Self(
        "copyPath",
        default: .init(.c, modifiers: [.command, .shift])
    )
    static let quitApp = Self(
        "quitApp",
        default: .init(.q, modifiers: [.command])
    )
    static let forceQuitApp = Self(
        "forceQuitApp",
        default: .init(.q, modifiers: [.command, .option])
    )
    static let restartApp = Self(
        "restartApp",
        default: .init(.r, modifiers: [.command])
    )
    static let deleteAction = Self(
        "deleteAction",
        default: .init(.delete, modifiers: [.command, .shift])
    )
    static let uninstallApp = Self(
        "uninstallApp",
        default: .init(.delete, modifiers: [.command, .option])
    )

    static let panelShortcutNames: [Self] = [
        .showActionMenu,
        .copySelectedResult,
        .focusPreview,
        .focusSearch,
        .showSelectionActions,
        .showNumberedActions,
        .favoriteAction,
        .revealInFinder,
        .copyName,
        .copyPath,
        .quitApp,
        .forceQuitApp,
        .restartApp,
        .deleteAction,
        .uninstallApp
    ]
}
