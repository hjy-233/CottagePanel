import AppKit
import Foundation
import SwiftUI

extension CottageState {
    var searchPlaceholder: String {
        guard let activeCustomAction else {
            return L10n.text("search.placeholder")
        }

        return activeCustomAction.definition.searchPlaceholder
    }

    var selectedCustomResult: CustomActionResult? {
        customResults.first { $0.id == selectedCustomResultID }
    }

    func runCustomAction(_ customAction: CustomAction) {
        guard confirmTrustedCustomActionIfNeeded(customAction) else {
            return
        }

        if let confirm = customAction.definition.confirm {
            confirmCustomAction(confirm, fallbackTitle: customAction.definition.title) { [weak self] in
                self?.runCustomActionAfterConfirmation(customAction)
            }
            return
        }

        runCustomActionAfterConfirmation(customAction)
    }

    private func confirmTrustedCustomActionIfNeeded(_ customAction: CustomAction) -> Bool {
        guard !customAction.isBuiltIn,
              let summary = CustomActionTrustStore.summary(for: customAction),
              !CustomActionTrustStore.isTrusted(customAction, summary: summary) else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = L10n.text("confirm.trustAction.title")
        alert.informativeText = trustSummaryText(for: customAction, summary: summary)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text("confirm.trustAction.trust"))
        alert.addButton(withTitle: L10n.text("confirm.destructive.cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else {
            focusSearch()
            return false
        }

        CustomActionTrustStore.trust(customAction, summary: summary)
        return true
    }

    private func trustSummaryText(for customAction: CustomAction, summary: CustomActionTrustSummary) -> String {
        let definition = customAction.definition
        let details = [
            "\(L10n.text("trustAction.summary.name")): \(definition.title)",
            "\(L10n.text("trustAction.summary.id")): \(definition.id)",
            "\(L10n.text("trustAction.summary.type")): \(definition.type.rawValue)",
            "\(L10n.text("trustAction.summary.presentation")): \(definition.presentation.rawValue)",
            "\(L10n.text("trustAction.summary.trigger")): \(definition.trigger.rawValue)",
            "\(L10n.text("trustAction.summary.command")): \(definition.command ?? "-")",
            "\(L10n.text("trustAction.summary.shell")): \(definition.type == .shell ? "yes" : "no")",
            "\(L10n.text("trustAction.summary.menuBar")): \(definition.menuBar?.enabled == true ? "yes" : "no")",
            "\(L10n.text("trustAction.summary.confirm")): \(definition.confirm?.enabled == true ? "yes" : "no")",
            "\(L10n.text("trustAction.summary.files")): \(summary.fileCount)",
            "\(L10n.text("trustAction.summary.path")): \(customAction.directoryURL.path)",
            "\(L10n.text("trustAction.summary.hash")): \(summary.fingerprint)"
        ]

        return details.joined(separator: "\n")
    }

    func runCustomActionAfterConfirmation(_ customAction: CustomAction) {
        switch customAction.definition.presentation {
        case .direct:
            hideWindow()
            CustomActionRunner.executeDirect(customAction)
            applyPostRun(customAction.definition.postRun)
        case .panel:
            enterCustomPanel(customAction)
            showStatus(L10n.text("status.actionOpened"))
        case .popup:
            showCustomPopup(customAction)
            showStatus(L10n.text("status.actionOpened"))
        case .form:
            enterCustomPanel(customAction)
            showStatus(L10n.text("status.actionOpened"))
        }
    }

    func runCustomMenuAction(_ menuAction: CustomMenuActionDefinition, for customAction: CustomAction) {
        if let confirm = menuAction.confirm {
            confirmCustomAction(confirm, fallbackTitle: menuAction.title) { [weak self] in
                self?.runCustomMenuActionAfterConfirmation(menuAction, for: customAction)
            }
            return
        }

        runCustomMenuActionAfterConfirmation(menuAction, for: customAction)
    }

    func runCustomMenuActionAfterConfirmation(
        _ menuAction: CustomMenuActionDefinition,
        for customAction: CustomAction
    ) {
        CustomActionRunner.executeMenuAction(menuAction, in: customAction)
        showStatus(L10n.text("status.executed"))
        if let postRun = menuAction.postRun {
            applyPostRun(postRun)
        }
        hideActionPalette()
    }

    func runCustomMenuAction(matching shortcut: CottageShortcut) -> Bool {
        if runCustomResultAction(matching: shortcut) {
            return true
        }

        guard let action = selectedAction,
              let customAction = action.customAction,
              let menuAction = menuAction(
                  matching: shortcut,
                  in: customAction.definition.actionMenuActions
              ) else {
            return false
        }

        runCustomMenuAction(menuAction, for: customAction)
        return true
    }

    func runCustomSelection() {
        guard let selectedCustomResult else {
            runActiveCustomActionInput()
            return
        }

        if runBuiltInSettingsResultIfNeeded(selectedCustomResult) {
            return
        }

        if runBuiltInWindowSwitcherResultIfNeeded(selectedCustomResult) {
            return
        }

        if restoreRecentSearchResultIfNeeded(selectedCustomResult) {
            return
        }

        if pushNavigationIfNeeded(selectedCustomResult) {
            return
        }

        showResultExecutionStatus(CustomActionRunner.executeResult(selectedCustomResult))
    }

    func runActiveCustomActionInput() {
        guard let activeCustomAction else {
            return
        }

        if activeCustomAction.definition.presentation == .form,
           !validateCustomForm(activeCustomAction) {
            return
        }

        runPanelCustomAction(activeCustomAction)
    }

    func customQueryDidChange() {
        guard !isRestoringCustomPanelCache else {
            return
        }

        guard let activeCustomAction else {
            return
        }

        if isBuiltInSettingsPanelActive {
            refreshBuiltInSettingsResults()
            return
        }

        if isBuiltInWindowSwitcherPanelActive {
            refreshBuiltInWindowSwitcherResults()
            return
        }

        guard activeCustomAction.definition.trigger == .live else {
            customResults = []
            selectedCustomResultID = nil
            return
        }

        customLiveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.runActiveCustomActionInput()
        }
        customLiveWorkItem = workItem
        let debounce = max(activeCustomAction.definition.input.debounceMilliseconds, 0)
        guard debounce > 0 else {
            workItem.perform()
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(debounce),
            execute: workItem
        )
    }

    func leaveCustomPanel() {
        saveActiveCustomPanelCache()
        customLiveWorkItem?.cancel()
        customLiveWorkItem = nil
        stopCustomProcess()
        activeCustomAction = nil
        customQuery = ""
        customAccessoryValue = ""
        customFormValues = [:]
        customNavigationStack = []
        customNavigationSourceResult = nil
        customResults = []
        selectedCustomResultID = nil
        shownCustomResultMenuID = nil
        isCustomActionRunning = false
        focusSearch()
    }

    func appendCustomLine(_ line: String) {
        customResultIndex += 1
        let result = customActionResult(from: line, fallbackID: "\(customResultIndex)")
        customResults.append(result)
        if selectedCustomResultID == nil {
            selectedCustomResultID = result.id
        }
        saveActiveCustomPanelCache()
    }

    func appendCustomError(_ text: String) {
        customResultIndex += 1
        customResults.append(
            CustomActionResult(
                id: "error.\(customResultIndex)",
                title: L10n.text("custom.result.failed"),
                subtitle: text,
                text: text,
                tags: [],
                url: nil,
                path: nil,
                previewImagePath: nil,
                command: nil,
                presentation: nil,
                navigationCommand: nil,
                navigation: nil,
                accessories: [],
                metadata: [],
                isError: true
            )
        )
        if selectedCustomResultID == nil {
            selectedCustomResultID = customResults.last?.id
        }
        saveActiveCustomPanelCache()
    }

    private func enterCustomPanel(_ customAction: CustomAction) {
        stopCustomProcess()
        activeCustomAction = customAction
        customAccessoryValue = defaultAccessoryValue(for: customAction)
        customFormValues = defaultFormValues(for: customAction)
        restoreCustomPanelCache(for: customAction)
        customResultIndex = customResults.count
        isCustomActionRunning = false
        showsActionPalette = false
        focusSearch()

        if customAction.definition.trigger == .live, customResults.isEmpty {
            customQueryDidChange()
        }
    }

    private func runPanelCustomAction(_ customAction: CustomAction) {
        if isBuiltInSettingsPanelActive {
            refreshBuiltInSettingsResults()
            return
        }

        if isBuiltInWindowSwitcherPanelActive {
            refreshBuiltInWindowSwitcherResults()
            return
        }

        if runNativeBuiltInPanelAction(customAction) {
            return
        }

        guard customAction.definition.input.allowsEmptyQuery || !customQuery.trimmedSearchText.isEmpty else {
            customResults = []
            selectedCustomResultID = nil
            shownCustomResultMenuID = nil
            showStatus(L10n.text("status.noResult"))
            return
        }

        customResults = []
        selectedCustomResultID = nil
        shownCustomResultMenuID = nil
        customResultIndex = 0
        isCustomActionRunning = true
        if customAction.definition.trigger == .manual {
            showStatus(L10n.text("status.running"))
        }
        stopCustomProcess()
        let processID = UUID()
        activeCustomProcessID = processID
        customProcess = CustomActionRunner.runProcess(
            CustomActionProcessRequest(
                customAction: customAction,
                query: customQuery,
                inputPayload: customInputPayload(for: customAction),
                environmentOverrides: customEnvironmentOverrides(),
                timeoutInterval: customAction.definition.trigger == .live ? 8 : 15,
                processID: processID
            ),
            handlers: panelHandlers(processID: processID, customAction: customAction)
        )

        if customProcess == nil {
            activeCustomProcessID = nil
            isCustomActionRunning = false
            appendCustomLine("{\"title\":\"\(L10n.text("custom.result.unsupported"))\"}")
            showStatus(L10n.text("status.actionFailed"))
        }
    }

    private func panelHandlers(
        processID: UUID,
        customAction: CustomAction
    ) -> CustomActionProcessHandlers {
        CustomActionProcessHandlers(
            onLine: { [weak self] line in
                guard let self, self.activeCustomProcessID == processID else {
                    return
                }

                self.appendCustomLine(line)
            },
            onError: { [weak self] errorText in
                guard let self, self.activeCustomProcessID == processID else {
                    return
                }

                self.appendCustomError(errorText)
            },
            onCompletion: { [weak self] status in
                self?.finishPanelRun(processID: processID, status: status, customAction: customAction)
            }
        )
    }

    private func finishPanelRun(
        processID: UUID,
        status: Int32,
        customAction: CustomAction
    ) {
        guard activeCustomProcessID == processID else {
            return
        }

        activeCustomProcessID = nil
        isCustomActionRunning = false
        if status != 0 {
            if !customResults.contains(where: \.isError) {
                appendCustomError("\(status)")
            }
            showStatus(L10n.text("status.actionFailed"))
        } else if customAction.definition.trigger == .manual {
            showStatus(L10n.text("status.done"))
            applyPostRun(customAction.definition.postRun)
        } else {
            applyPostRun(customAction.definition.postRun)
        }
    }

}
