// 实现 action panel 内的 push 和 pop 导航
import Foundation
import SwiftUI

extension CottageState {
    func updateSearchAccessory(_ value: String) {
        customAccessoryValue = value
        saveSearchAccessoryValue(value)
        scheduleRecentSearchCapture()
        guard activeCustomAction?.definition.trigger == .live else {
            return
        }

        customQueryDidChange()
    }

    func updateFormValue(fieldID: String, value: String) {
        customFormValues[fieldID] = value
    }

    func pushNavigationIfNeeded(_ result: CustomActionResult) -> Bool {
        let shouldNavigate = result.presentation == .panel
            || result.navigationCommand?.isEmpty == false
            || result.navigation?.command.isEmpty == false
        guard shouldNavigate,
              customNavigationStack.count < 8,
              let activeCustomAction else {
            return false
        }

        if let nextAction = builtInSettingsNavigationAction(from: result, baseAction: activeCustomAction) {
            customNavigationStack.append(snapshot(for: activeCustomAction))
            prepareNavigatedPanel(nextAction, sourceResult: result)
            return true
        }

        customNavigationStack.append(snapshot(for: activeCustomAction))
        let nextAction = navigationAction(from: result, baseAction: activeCustomAction)
        prepareNavigatedPanel(nextAction, sourceResult: result)
        return true
    }

    func popCustomNavigationStack() -> Bool {
        guard let previous = customNavigationStack.popLast() else {
            return false
        }

        stopCustomProcess()
        restoreNavigationState(previous)
        focusSearch()
        return true
    }

    func menuAction(
        matching shortcut: CottageShortcut,
        in actions: [CustomMenuActionDefinition]
    ) -> CustomMenuActionDefinition? {
        for action in actions {
            if CottageShortcut(action.shortcut) == shortcut {
                return action
            }
            if let child = menuAction(matching: shortcut, in: action.children) {
                return child
            }
        }
        return nil
    }

    func defaultAccessoryValue(for customAction: CustomAction) -> String {
        guard let accessory = customAction.definition.searchAccessory else {
            return ""
        }

        let key = searchAccessorySettingsKey(for: customAction, accessoryID: accessory.id)
        if let savedValue = customAccessoryValues[key],
           accessory.items.contains(where: { $0.id == savedValue }) {
            return savedValue
        }

        if accessory.items.contains(where: { $0.id == accessory.defaultValue }) {
            return accessory.defaultValue
        }
        return accessory.items.first?.id ?? ""
    }

    func searchAccessorySettingsKey(for customAction: CustomAction, accessoryID: String) -> String {
        "\(customAction.definition.id).\(accessoryID)"
    }

    private func saveSearchAccessoryValue(_ value: String) {
        guard let activeCustomAction,
              let accessory = activeCustomAction.definition.searchAccessory,
              accessory.items.contains(where: { $0.id == value }) else {
            return
        }

        customAccessoryValues[searchAccessorySettingsKey(for: activeCustomAction, accessoryID: accessory.id)] = value
        saveSettings()
    }

    func defaultFormValues(for customAction: CustomAction) -> [String: String] {
        var values: [String: String] = [:]
        customAction.definition.form?.fields.forEach { field in
            values[field.id] = field.defaultValue ?? (field.type == .checkbox ? "false" : "")
        }
        return values
    }

    func validateCustomForm(_ customAction: CustomAction) -> Bool {
        guard let form = customAction.definition.form else {
            return true
        }

        let invalidField = form.fields.first { field in
            field.required && (customFormValues[field.id] ?? "").trimmedSearchText.isEmpty
        }
        if let invalidField {
            showStatus(invalidField.title)
            return false
        }
        return true
    }

    func customEnvironmentOverrides() -> [String: String] {
        var values: [String: String] = [:]
        if let accessory = activeCustomAction?.definition.searchAccessory {
            values[accessory.environmentName] = customAccessoryValue
        }
        environmentFormValues().forEach { key, value in
            values["COTTAGE_FORM_\(normalizedEnvironmentKey(key))"] = value
        }
        return values
    }

    func customInputPayload(
        for customAction: CustomAction,
        result: CustomActionResult? = nil
    ) -> CustomActionInputPayload {
        var accessory: [String: String] = [:]
        if let accessoryDefinition = customAction.definition.searchAccessory {
            accessory[accessoryDefinition.id] = customAccessoryValue
        }

        return CustomActionInputPayload(
            apiVersion: customAction.definition.apiVersion,
            query: customQuery,
            form: customFormValues,
            accessory: accessory,
            result: (result ?? customNavigationSourceResult).map(CustomActionResultInputPayload.init),
            navigation: navigationPayload(for: customAction, result: result ?? customNavigationSourceResult)
        )
    }

    private func snapshot(for customAction: CustomAction) -> CustomPanelNavigationState {
        CustomPanelNavigationState(
            action: customAction,
            query: customQuery,
            accessoryValue: customAccessoryValue,
            formValues: customFormValues,
            results: customResults,
            selectedResultID: selectedCustomResultID,
            resultIndex: customResultIndex,
            sourceResult: customNavigationSourceResult
        )
    }

    private func prepareNavigatedPanel(_ customAction: CustomAction, sourceResult: CustomActionResult) {
        stopCustomProcess()
        activeCustomAction = customAction
        customNavigationSourceResult = sourceResult
        customQuery = ""
        customAccessoryValue = defaultAccessoryValue(for: customAction)
        customFormValues = defaultFormValues(for: customAction)
        customResults = []
        selectedCustomResultID = nil
        shownCustomResultMenuID = nil
        customResultIndex = 0
        isCustomActionRunning = false
        focusSearch()
        if customAction.definition.trigger == .live {
            customQueryDidChange()
        }
    }

    private func restoreNavigationState(_ previous: CustomPanelNavigationState) {
        activeCustomAction = previous.action
        customNavigationSourceResult = previous.sourceResult
        isRestoringCustomPanelCache = true
        customQuery = previous.query
        isRestoringCustomPanelCache = false
        customAccessoryValue = previous.accessoryValue
        customFormValues = previous.formValues
        customResults = previous.results
        selectedCustomResultID = previous.selectedResultID
        customResultIndex = previous.resultIndex
        shownCustomResultMenuID = nil
        isCustomActionRunning = false
    }

    private func navigationAction(from result: CustomActionResult, baseAction: CustomAction) -> CustomAction {
        let navigationCommand = result.navigation?.command ?? result.navigationCommand
        guard let navigationCommand, !navigationCommand.isEmpty else {
            return baseAction
        }

        let definition = CustomActionDefinition(
            id: "\(baseAction.definition.id).navigation.\(result.id)",
            title: result.navigation?.title ?? result.title,
            subtitle: result.subtitle,
            placeholder: result.navigation?.searchPlaceholder ?? baseAction.definition.placeholder,
            symbolName: baseAction.definition.symbolName,
            icon: baseAction.definition.icon,
            tags: baseAction.definition.tags,
            type: .script,
            command: navigationCommand,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: result.navigation?.trigger ?? .manual,
            resultActions: baseAction.definition.resultActions,
            preview: baseAction.definition.preview,
            input: baseAction.definition.input
        )
        return CustomAction(definition: definition, directoryURL: baseAction.directoryURL)
    }

    private func environmentFormValues() -> [String: String] {
        guard let fields = activeCustomAction?.definition.form?.fields else {
            return customFormValues
        }

        let sensitiveTypes: Set<CustomFormFieldType> = [.password, .textarea]
        let sensitiveIDs = Set(fields.filter { sensitiveTypes.contains($0.type) }.map(\.id))
        return customFormValues.filter { key, _ in
            !sensitiveIDs.contains(key)
        }
    }

    private func navigationPayload(
        for customAction: CustomAction,
        result: CustomActionResult?
    ) -> CustomActionNavigationInputPayload? {
        guard let result else {
            return nil
        }

        return CustomActionNavigationInputPayload(
            sourceActionId: customAction.definition.id,
            sourceResultId: result.id,
            depth: customNavigationStack.count
        )
    }
}
