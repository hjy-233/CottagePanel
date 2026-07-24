import AppKit
import KeyboardShortcuts

extension CottageState {
    func settingsCottageAction() -> CottageAction {
        let customAction = settingsRootCustomAction()
        return CottageAction(
            id: "built-in.settings",
            title: L10n.text("settings.action.title"),
            subtitle: L10n.text("settings.action.subtitle"),
            symbolName: "slider.horizontal.3",
            kind: .command,
            icon: CottageAppIcon.image(),
            fileURL: configDirectory,
            customAction: customAction,
            tags: ["settings", "cottage", L10n.text("tag.settings")]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }

    var isBuiltInSettingsPanelActive: Bool {
        activeCustomAction?.definition.id.hasPrefix(Self.settingsActionIDPrefix) == true
    }

    var isBuiltInSettingsExportPanelActive: Bool {
        activeCustomAction?.definition.id == Self.settingsExportActionID
    }

    func runBuiltInSettingsResultIfNeeded(_ result: CustomActionResult) -> Bool {
        guard isBuiltInSettingsPanelActive else {
            return false
        }

        if runBuiltInSettingsExportResultIfNeeded(result) {
            return true
        }

        if let category = settingCategoryID(from: result.command) {
            pushBuiltInSettingsCategory(category, sourceResult: result)
            return true
        }

        guard let command = result.command else {
            return false
        }

        if settingsShortcutName(for: result) != nil {
            focusSettingsShortcutRecorder(for: result)
            return true
        }

        runBuiltInSettingsCommand(command)
        refreshBuiltInSettingsResults()
        return true
    }

    func refreshBuiltInSettingsResults() {
        guard isBuiltInSettingsPanelActive else {
            return
        }

        let previousSelectedID = selectedCustomResultID
        let results = isBuiltInSettingsExportPanelActive
            ? exportPanelResults(query: customQuery)
            : settingsResults(categoryID: activeSettingsCategoryID(), query: customQuery)
        customResults = results
        selectedCustomResultID = results.contains { $0.id == previousSelectedID }
            ? previousSelectedID
            : results.first?.id
        shownCustomResultMenuID = nil
        customResultIndex = results.count
        isCustomActionRunning = false
    }

    func refreshBuiltInSettingsPanelLanguage() {
        guard isBuiltInSettingsPanelActive else {
            return
        }

        if isBuiltInSettingsExportPanelActive {
            activeCustomAction = settingsExportCustomAction()
        } else if let categoryID = activeSettingsCategoryID(),
                  let category = SettingsCategory(rawValue: categoryID) {
            activeCustomAction = settingsCategoryCustomAction(category)
        } else {
            activeCustomAction = settingsRootCustomAction()
        }

        refreshBuiltInSettingsResults()
    }

    func builtInSettingsNavigationAction(
        from result: CustomActionResult,
        baseAction: CustomAction
    ) -> CustomAction? {
        guard baseAction.definition.id.hasPrefix(Self.settingsActionIDPrefix),
              let category = settingCategoryID(from: result.command) else {
            return nil
        }

        return settingsCategoryCustomAction(category)
    }
}

extension CottageState {
    func settingsShortcutName(for result: CustomActionResult?) -> KeyboardShortcuts.Name? {
        guard let command = result?.command,
              command.hasPrefix("cottage-settings:shortcut:") else {
            return nil
        }

        let id = String(command.dropFirst("cottage-settings:shortcut:".count))
        return shortcutItems().first { $0.id == id }?.name
    }

    func shortcutRecorderFocusTrigger(for result: CustomActionResult) -> Int {
        focusedSettingsShortcutResultID == result.id ? settingsShortcutRecorderFocusTrigger : 0
    }

    private func focusSettingsShortcutRecorder(for result: CustomActionResult) {
        selectedCustomResultID = result.id
        focusedSettingsShortcutResultID = result.id
        settingsShortcutRecorderFocusTrigger += 1
    }

    func adjustBuiltInSettingSelection(direction: CottageSettingAdjustmentDirection) -> Bool {
        guard isBuiltInSettingsPanelActive,
              let command = selectedCustomResult?.command,
              command.hasPrefix("cottage-settings:step:")
                || command.hasPrefix("cottage-settings:cycle:") else {
            return false
        }

        runBuiltInSettingsCommand(command, direction: direction)
        refreshBuiltInSettingsResults()
        return true
    }
}

enum CottageSettingAdjustmentDirection {
    case previous
    case next
}

extension CottageState {
    static let settingsActionIDPrefix = "built-in-settings"
    static let settingsExportActionID = "built-in-settings.export"

    func settingsRootCustomAction() -> CustomAction {
        settingsCustomAction(
            id: Self.settingsActionIDPrefix,
            title: L10n.text("settings.action.title"),
            subtitle: L10n.text("settings.action.subtitle"),
            placeholder: L10n.text("settings.panelAction.placeholder")
        )
    }

    func settingsCategoryCustomAction(_ category: SettingsCategory) -> CustomAction {
        settingsCustomAction(
            id: "\(Self.settingsActionIDPrefix).\(category.id)",
            title: category.title,
            subtitle: category.subtitle,
            placeholder: String(format: L10n.text("settings.panelAction.categoryPlaceholder"), category.title)
        )
    }

    func settingsExportCustomAction() -> CustomAction {
        settingsCustomAction(
            id: Self.settingsExportActionID,
            title: L10n.text("settings.exportActions"),
            subtitle: L10n.text("actions.export.select.message"),
            placeholder: L10n.text("actions.export.panel.placeholder")
        )
    }

    func settingsCustomAction(
        id: String,
        title: String,
        subtitle: String,
        placeholder: String
    ) -> CustomAction {
        let definition = CustomActionDefinition(
            id: id,
            title: title,
            subtitle: subtitle,
            placeholder: placeholder,
            symbolName: "slider.horizontal.3",
            icon: nil,
            tags: ["settings", "cottage", L10n.text("tag.settings")],
            type: .script,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            preview: CustomActionPreviewDefinition(style: .text),
            input: CustomActionInputDefinition(
                placeholder: placeholder,
                debounceMilliseconds: 0,
                allowsEmptyQuery: true
            )
        )
        return CustomAction(definition: definition, directoryURL: configDirectory)
    }

    func activeSettingsCategoryID() -> String? {
        guard let id = activeCustomAction?.definition.id,
              id.hasPrefix("\(Self.settingsActionIDPrefix).") else {
            return nil
        }

        return String(id.dropFirst(Self.settingsActionIDPrefix.count + 1))
    }

    func settingCategoryID(from command: String?) -> SettingsCategory? {
        guard let command,
              command.hasPrefix("cottage-settings:category:") else {
            return nil
        }

        let id = String(command.dropFirst("cottage-settings:category:".count))
        return SettingsCategory.allCases.first { $0.id == id }
    }

    func pushBuiltInSettingsCategory(
        _ category: SettingsCategory,
        sourceResult: CustomActionResult
    ) {
        customNavigationStack.append(
            CustomPanelNavigationState(
                action: activeCustomAction ?? settingsRootCustomAction(),
                query: customQuery,
                accessoryValue: customAccessoryValue,
                formValues: customFormValues,
                results: customResults,
                selectedResultID: selectedCustomResultID,
                resultIndex: customResultIndex,
                sourceResult: customNavigationSourceResult
            )
        )
        stopCustomProcess()
        activeCustomAction = settingsCategoryCustomAction(category)
        customNavigationSourceResult = sourceResult
        customQuery = ""
        customResults = []
        selectedCustomResultID = nil
        shownCustomResultMenuID = nil
        customResultIndex = 0
        isCustomActionRunning = false
        refreshBuiltInSettingsResults()
        focusSearch()
    }

    func enterBuiltInSettingsExportPanel() {
        customNavigationStack.append(
            CustomPanelNavigationState(
                action: activeCustomAction ?? settingsRootCustomAction(),
                query: customQuery,
                accessoryValue: customAccessoryValue,
                formValues: customFormValues,
                results: customResults,
                selectedResultID: selectedCustomResultID,
                resultIndex: customResultIndex,
                sourceResult: customNavigationSourceResult
            )
        )
        stopCustomProcess()
        activeCustomAction = settingsExportCustomAction()
        customNavigationSourceResult = nil
        customQuery = ""
        customResults = []
        selectedCustomResultID = nil
        shownCustomResultMenuID = nil
        customResultIndex = 0
        isCustomActionRunning = false
        refreshBuiltInSettingsResults()
        focusSearch()
    }

    func settingsResults(categoryID: String?, query: String) -> [CustomActionResult] {
        let items = categoryID.flatMap(settingsItems(in:)) ?? categoryItems()
        let trimmedQuery = query.trimmedSearchText
        guard !trimmedQuery.isEmpty else {
            return items.map(\.result)
        }

        let initials = normalizedSearchText(trimmedQuery)
        return items
            .filter { $0.matches(trimmedQuery, initials: initials) }
            .map(\.result)
    }

    func categoryItems() -> [SettingsPanelItem] {
        SettingsCategory.allCases.map { category in
            SettingsPanelItem(
                id: "category.\(category.id)",
                title: category.title,
                subtitle: category.subtitle,
                text: category.text,
                symbolName: category.symbolName,
                command: "cottage-settings:category:\(category.id)",
                presentation: .panel,
                tags: category.tags,
                metadata: [
                    CustomResultMetadata(
                        label: L10n.text("settings.panelAction.metadata.type"),
                        value: L10n.text("settings.panelAction.metadata.category"),
                        type: nil,
                        url: nil
                    )
                ]
            )
        }
    }

    func settingsItems(in categoryID: String) -> [SettingsPanelItem] {
        guard let category = SettingsCategory.allCases.first(where: { $0.id == categoryID }) else {
            return []
        }

        switch category {
        case .panel:
            return panelSettingsItems()
        case .actions:
            return actionSettingsItems()
        case .shortcuts:
            return shortcutSettingsItems()
        case .keyboard:
            return keyboardSettingsItems()
        case .security:
            return securitySettingsItems()
        }
    }
}
