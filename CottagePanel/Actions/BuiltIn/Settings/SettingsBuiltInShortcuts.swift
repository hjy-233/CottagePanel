// 生成设置面板里的快捷键录入项
import KeyboardShortcuts

extension CottageState {
    func shortcutItems() -> [SettingsShortcutItem] {
        primaryShortcutItems() + secondaryShortcutItems()
    }

    private func primaryShortcutItems() -> [SettingsShortcutItem] {
        [
            SettingsShortcutItem(
                id: "togglePanel",
                title: L10n.text("settings.togglePanelShortcut"),
                name: .togglePanel
            ),
            SettingsShortcutItem(
                id: "showActionMenu",
                title: L10n.text("settings.shortcut.showActionMenu"),
                name: .showActionMenu
            ),
            SettingsShortcutItem(
                id: "copySelectedResult",
                title: L10n.text("settings.shortcut.copySelectedResult"),
                name: .copySelectedResult
            ),
            SettingsShortcutItem(
                id: "focusPreview",
                title: L10n.text("settings.shortcut.focusPreview"),
                name: .focusPreview
            ),
            SettingsShortcutItem(
                id: "focusSearch",
                title: L10n.text("settings.shortcut.focusSearch"),
                name: .focusSearch
            ),
            SettingsShortcutItem(
                id: "showSelectionActions",
                title: L10n.text("settings.shortcut.showSelectionActions"),
                name: .showSelectionActions
            ),
            SettingsShortcutItem(
                id: "showNumberedActions",
                title: L10n.text("settings.shortcut.showNumberedActions"),
                name: .showNumberedActions
            )
        ]
    }

    private func secondaryShortcutItems() -> [SettingsShortcutItem] {
        [
            SettingsShortcutItem(
                id: "favoriteAction",
                title: L10n.text("settings.shortcut.favoriteAction"),
                name: .favoriteAction
            ),
            SettingsShortcutItem(
                id: "revealInFinder",
                title: L10n.text("settings.shortcut.revealInFinder"),
                name: .revealInFinder
            ),
            SettingsShortcutItem(id: "copyName", title: L10n.text("settings.shortcut.copyName"), name: .copyName),
            SettingsShortcutItem(id: "copyPath", title: L10n.text("settings.shortcut.copyPath"), name: .copyPath),
            SettingsShortcutItem(id: "quitApp", title: L10n.text("settings.shortcut.quitApp"), name: .quitApp),
            SettingsShortcutItem(
                id: "forceQuitApp",
                title: L10n.text("settings.shortcut.forceQuitApp"),
                name: .forceQuitApp
            ),
            SettingsShortcutItem(
                id: "restartApp",
                title: L10n.text("settings.shortcut.restartApp"),
                name: .restartApp
            ),
            SettingsShortcutItem(
                id: "deleteAction",
                title: L10n.text("settings.shortcut.deleteAction"),
                name: .deleteAction
            ),
            SettingsShortcutItem(
                id: "uninstallApp",
                title: L10n.text("settings.shortcut.uninstallApp"),
                name: .uninstallApp
            )
        ]
    }
}
