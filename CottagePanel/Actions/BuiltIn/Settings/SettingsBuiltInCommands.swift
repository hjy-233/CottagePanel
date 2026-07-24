import KeyboardShortcuts

extension CottageState {
    func runBuiltInSettingsCommand(_ command: String) {
        runBuiltInSettingsCommand(command, direction: .next)
    }

    func runBuiltInSettingsCommand(
        _ command: String,
        direction: CottageSettingAdjustmentDirection
    ) {
        if runBuiltInSettingsToggle(command) {
            return
        }
        if runBuiltInSettingsStep(command, direction: direction) {
            return
        }
        if runBuiltInSettingsCycle(command, direction: direction) {
            return
        }
        if runBuiltInSettingsAction(command) {
            return
        }
        showStatus(L10n.text("status.noResult"))
    }
}

private extension CottageState {
    func runBuiltInSettingsToggle(_ command: String) -> Bool {
        switch command {
        case "cottage-settings:toggle:showKeyboardHints":
            showsKeyboardHints.toggle()
        case "cottage-settings:toggle:opensPanelOnLaunch":
            opensPanelOnLaunch.toggle()
        case "cottage-settings:toggle:restoresPanelSession":
            restoresPanelSession.toggle()
        case "cottage-settings:toggle:fuzzySearchEnabled":
            fuzzySearchEnabled.toggle()
        case "cottage-settings:toggle:queryChipsEnabled":
            queryChipsEnabled.toggle()
        case "cottage-settings:toggle:droppedInputEnabled":
            droppedInputEnabled.toggle()
        case "cottage-settings:toggle:keyboardOnlyModeEnabled":
            keyboardOnlyModeEnabled.toggle()
        case "cottage-settings:toggle:confirmsDestructiveActions":
            confirmsDestructiveActions.toggle()
        default:
            return false
        }
        return true
    }

    func runBuiltInSettingsStep(
        _ command: String,
        direction: CottageSettingAdjustmentDirection
    ) -> Bool {
        switch command {
        case "cottage-settings:step:panelSessionRestoreSeconds":
            panelSessionRestoreSeconds = adjusted(
                panelSessionRestoreSeconds,
                values: [5, 10, 15, 30, 60, 120, 300],
                direction: direction
            )
        case "cottage-settings:step:panelWidth":
            panelWidth = adjusted(
                panelWidth,
                values: strideValues(from: 560, through: 980, by: 20),
                direction: direction
            )
        case "cottage-settings:step:panelHeight":
            panelHeight = adjusted(
                panelHeight,
                values: strideValues(from: 360, through: 720, by: 20),
                direction: direction
            )
        default:
            return false
        }
        return true
    }

    func runBuiltInSettingsCycle(
        _ command: String,
        direction: CottageSettingAdjustmentDirection
    ) -> Bool {
        switch command {
        case "cottage-settings:cycle:appLanguage":
            appLanguage = adjusted(appLanguage, direction: direction)
        case "cottage-settings:cycle:panelNavigationScheme":
            panelNavigationScheme = adjusted(panelNavigationScheme, direction: direction)
        case "cottage-settings:cycle:menuNavigationScheme":
            menuNavigationScheme = adjusted(menuNavigationScheme, direction: direction)
        case "cottage-settings:cycle:previewScrollScheme":
            previewScrollScheme = adjusted(previewScrollScheme, direction: direction)
        default:
            return false
        }
        return true
    }

    func runBuiltInSettingsAction(_ command: String) -> Bool {
        switch command {
        case "cottage-settings:action:openConfig":
            openConfigDirectory()
        case "cottage-settings:action:openActions":
            openActionsDirectory()
        case "cottage-settings:action:reloadActions":
            reloadActionsFromUserAction()
        case "cottage-settings:action:importActions":
            importActionsArchive()
        case "cottage-settings:action:exportActions":
            exportActionsArchive()
        case "cottage-settings:action:resetShortcuts":
            KeyboardShortcuts.reset(KeyboardShortcuts.Name.panelShortcutNames)
            showStatus(L10n.text("status.done"))
        default:
            return false
        }
        return true
    }

    func strideValues(from start: Double, through end: Double, by step: Double) -> [Double] {
        var values: [Double] = []
        var value = start
        while value <= end {
            values.append(value)
            value += step
        }
        return values
    }

    func adjusted(
        _ current: Double,
        values: [Double],
        direction: CottageSettingAdjustmentDirection
    ) -> Double {
        guard let index = values.firstIndex(where: { $0 >= current }) else {
            return values.first ?? current
        }
        let offset = direction == .next ? 1 : -1
        return values[(index + offset + values.count) % values.count]
    }

    func adjusted<T: CaseIterable & Equatable>(
        _ current: T,
        direction: CottageSettingAdjustmentDirection
    ) -> T {
        let values = Array(T.allCases)
        guard let index = values.firstIndex(of: current) else {
            return values.first ?? current
        }
        let offset = direction == .next ? 1 : -1
        return values[(index + offset + values.count) % values.count]
    }
}
