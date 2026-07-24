import KeyboardShortcuts

extension CottageState {
    func panelSettingsItems() -> [SettingsPanelItem] {
        [
            toggleItem(
                id: "show-keyboard-hints",
                titleKey: "settings.showKeyboardHints",
                value: showsKeyboardHints,
                command: "cottage-settings:toggle:showKeyboardHints",
                tags: ["keyboard", "hints"]
            ),
            toggleItem(
                id: "open-panel-on-launch",
                titleKey: "settings.openPanelOnLaunch",
                value: opensPanelOnLaunch,
                command: "cottage-settings:toggle:opensPanelOnLaunch",
                tags: ["launch", "startup"]
            ),
            toggleItem(
                id: "restore-panel-session",
                titleKey: "settings.restorePanelSession",
                value: restoresPanelSession,
                command: "cottage-settings:toggle:restoresPanelSession",
                tags: ["restore", "session"]
            ),
            restoreSecondsItem(),
            cycleItem(
                id: "app-language",
                titleKey: "settings.language",
                value: appLanguage.title,
                command: "cottage-settings:cycle:appLanguage",
                tags: ["language", "locale", "i18n"]
            ),
            stepItem(
                id: "panel-width",
                title: String(format: L10n.text("settings.panel.width"), Int(panelWidth)),
                command: "cottage-settings:step:panelWidth",
                tags: ["panel", "width"]
            ),
            stepItem(
                id: "panel-height",
                title: String(format: L10n.text("settings.panel.height"), Int(panelHeight)),
                command: "cottage-settings:step:panelHeight",
                tags: ["panel", "height"]
            )
        ] + inputSettingsItems()
    }

    func actionSettingsItems() -> [SettingsPanelItem] {
        [
            actionItem(
                id: "open-config",
                titleKey: "settings.openConfig",
                subtitle: configDirectory.path,
                symbolName: "folder.badge.gearshape",
                command: "cottage-settings:action:openConfig"
            ),
            actionItem(
                id: "open-actions",
                titleKey: "settings.openActions",
                subtitle: configDirectory.appendingPathComponent("actions", isDirectory: true).path,
                symbolName: "folder",
                command: "cottage-settings:action:openActions"
            ),
            actionItem(
                id: "reload-actions",
                titleKey: "settings.reloadActions",
                subtitle: L10n.text("action.reloadActions.subtitle"),
                symbolName: "arrow.clockwise",
                command: "cottage-settings:action:reloadActions"
            ),
            actionItem(
                id: "import-actions",
                titleKey: "settings.importActions",
                subtitle: L10n.text("actions.import.message"),
                symbolName: "square.and.arrow.down",
                command: "cottage-settings:action:importActions"
            ),
            actionItem(
                id: "export-actions",
                titleKey: "settings.exportActions",
                subtitle: L10n.text("actions.export.message"),
                symbolName: "square.and.arrow.up",
                command: "cottage-settings:action:exportActions"
            )
        ]
    }

    func shortcutSettingsItems() -> [SettingsPanelItem] {
        shortcutItems().map(shortcutItem) + [
            actionItem(
                id: "reset-shortcuts",
                titleKey: "settings.shortcuts.reset",
                subtitle: L10n.text("settings.shortcuts.help"),
                symbolName: "arrow.counterclockwise",
                command: "cottage-settings:action:resetShortcuts"
            )
        ]
    }

    func keyboardSettingsItems() -> [SettingsPanelItem] {
        [
            toggleItem(
                id: "keyboard-only-mode",
                titleKey: "settings.keyboard.enabled",
                value: keyboardOnlyModeEnabled,
                command: "cottage-settings:toggle:keyboardOnlyModeEnabled",
                tags: ["keyboard", "only"]
            ),
            cycleItem(
                id: "panel-navigation",
                titleKey: "settings.keyboard.panelNavigation",
                value: panelNavigationScheme.title,
                command: "cottage-settings:cycle:panelNavigationScheme",
                tags: ["navigation", "panel"]
            ),
            cycleItem(
                id: "menu-navigation",
                titleKey: "settings.keyboard.menuNavigation",
                value: menuNavigationScheme.title,
                command: "cottage-settings:cycle:menuNavigationScheme",
                tags: ["navigation", "menu"]
            ),
            cycleItem(
                id: "preview-scroll",
                titleKey: "settings.keyboard.previewScroll",
                value: previewScrollScheme.title,
                command: "cottage-settings:cycle:previewScrollScheme",
                tags: ["preview", "scroll"]
            )
        ]
    }

    func securitySettingsItems() -> [SettingsPanelItem] {
        [
            toggleItem(
                id: "confirm-destructive-actions",
                titleKey: "settings.confirmDestructiveActions",
                value: confirmsDestructiveActions,
                command: "cottage-settings:toggle:confirmsDestructiveActions",
                tags: ["confirm", "destructive", "security"]
            )
        ]
    }
}

private extension CottageState {
    func inputSettingsItems() -> [SettingsPanelItem] {
        [
            toggleItem(
                id: "fuzzy-search",
                titleKey: "settings.fuzzySearch",
                value: fuzzySearchEnabled,
                command: "cottage-settings:toggle:fuzzySearchEnabled",
                tags: ["search", "fuzzy"]
            ),
            toggleItem(
                id: "query-chips",
                titleKey: "settings.queryChips",
                value: queryChipsEnabled,
                command: "cottage-settings:toggle:queryChipsEnabled",
                tags: ["search", "chip", "slash"]
            ),
            toggleItem(
                id: "dropped-input",
                titleKey: "settings.droppedInput",
                value: droppedInputEnabled,
                command: "cottage-settings:toggle:droppedInputEnabled",
                tags: ["drag", "drop", "input"]
            )
        ]
    }

    func restoreSecondsItem() -> SettingsPanelItem {
        stepItem(
            id: "restore-panel-seconds",
            title: String(
                format: L10n.text("settings.restorePanelSeconds"),
                Int(panelSessionRestoreSeconds)
            ),
            command: "cottage-settings:step:panelSessionRestoreSeconds",
            tags: ["restore", "seconds", "timeout"]
        )
    }

    func shortcutItem(_ shortcut: SettingsShortcutItem) -> SettingsPanelItem {
        let label = KeyboardShortcuts.getShortcut(for: shortcut.name)
            .map { "\($0)" } ?? L10n.text("settings.shortcut.notSet")
        return SettingsPanelItem(
            id: "shortcut.\(shortcut.id)",
            title: shortcut.title,
            subtitle: label,
            text: L10n.text("settings.shortcut.openRecorderHelp"),
            symbolName: "keyboard",
            command: "cottage-settings:shortcut:\(shortcut.id)",
            tags: ["shortcut", shortcut.id],
            metadata: [
                CustomResultMetadata(
                    label: L10n.text("settings.panelAction.metadata.current"),
                    value: label,
                    type: "code",
                    url: nil
                )
            ]
        )
    }
}
