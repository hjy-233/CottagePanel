import AppKit
import SwiftUI

extension CottageState {
    func focusSearch() {
        searchFocusTrigger += 1
    }

    func updateActionBadgeMode(width: CGFloat) {
        let shouldShowText = width >= 340
        guard actionBadgesShowText != shouldShowText else {
            return
        }

        actionBadgesShowText = shouldShowText
    }

    func select(_ action: CottageAction) {
        selectedActionID = action.id
    }

    func showActionsForSelection() {
        if activeCustomAction != nil {
            if let selectedCustomResult {
                showCustomResultMenu(for: selectedCustomResult)
            }
            return
        }

        guard selectedAction != nil else {
            return
        }

        showsActionPalette = true
        keyboardContext = .actionMenu
    }

    func showActionMenuShortcut() {
        if activeCustomAction != nil {
            showsActionPalette = false
            shownCustomResultMenuID = nil
            showsAppMenu = true
            keyboardContext = .actionMenu
            return
        }

        showActionsForSelection()
    }

    func hideActionPalette() {
        showsActionPalette = false
        shownCustomResultMenuID = nil
        keyboardContext = .search
        focusSearch()
    }

    func showStatus(_ message: String) {
        statusWorkItem?.cancel()
        statusMessage = message
        let workItem = DispatchWorkItem { [weak self] in
            self?.statusMessage = ""
            self?.statusWorkItem = nil
        }
        statusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    func copyText(_ text: String) {
        copyToPasteboard(text)
        showStatus(L10n.text("status.copied"))
    }

    func prepareForPanelRestore() {
        ensureConfigDirectory()
        showsActionPalette = false
        showsAppMenu = false
        showsCommandActionHints = false
        closeCustomPopup()
        if activeCustomAction == nil {
            selectedActionID = filteredActions.first { $0.id == selectedActionID }?.id
                ?? filteredActions.first?.id
        }
        focusSearch()
    }

    func hideWindow() {
        showsActionPalette = false
        showsCommandActionHints = false
        cancelQuestionNumberPrefix()
        closeCustomPopup()
        leaveCustomPanel()
        hidePanel?()
    }

    func handleEscape() {
        if showsCustomPopup {
            closeCustomPopup()
            return
        }

        if activeCustomAction != nil {
            if popCustomNavigationStack() {
                return
            }
            leaveCustomPanel()
            return
        }

        hideWindow()
    }

    func openSettings() {
        showPanelForSettingsAction()
        focusSearch()
    }

    func openSettingsFromMenu() {
        showsAppMenu = false
        openSettings()
    }

    func quitFromMenu() {
        showsAppMenu = false
        quitApp?()
    }

    func moveSelection(_ direction: MoveCommandDirection) {
        if activeCustomAction != nil {
            moveCustomResultSelection(direction)
            return
        }

        guard !filteredActions.isEmpty else {
            selectedActionID = nil
            return
        }

        let currentIndex = filteredActions.firstIndex { $0.id == selectedActionID } ?? 0
        switch direction {
        case .up:
            selectedActionID = filteredActions[max(currentIndex - 1, 0)].id
        case .down:
            selectedActionID = filteredActions[min(currentIndex + 1, filteredActions.count - 1)].id
        default:
            break
        }
    }

    func runSelection() {
        if activeCustomAction != nil {
            runCustomSelection()
            return
        }

        if runQuickQueryIfNeeded() {
            return
        }

        guard let action = filteredActions.first(where: { $0.id == selectedActionID }) else {
            showStatus(L10n.text("status.noSelection"))
            return
        }

        run(action)
    }

    func run(_ action: CottageAction) {
        recordExecution(action)
        if let customAction = action.customAction {
            runCustomAction(customAction)
            return
        }

        hideWindow()
        action.run()
    }

    func showPanelForSettingsAction() {
        query = ""
        if activeCustomAction == nil {
            selectedActionID = "built-in.settings"
        }
        guard let settingsAction = actions.first(where: { $0.id == "built-in.settings" }) else {
            showSettings?()
            return
        }
        run(settingsAction)
    }

    func isFavorite(_ action: CottageAction) -> Bool {
        favoriteActionIDs.contains(action.id)
    }

    func toggleFavorite(_ action: CottageAction) {
        if favoriteActionIDs.contains(action.id) {
            favoriteActionIDs.remove(action.id)
        } else {
            favoriteActionIDs.insert(action.id)
        }

        saveSettings()
        actions = sortedActions(actions)
    }

    func deleteAction(_ action: CottageAction) {
        confirmDestructiveAction(
            title: L10n.text("confirm.deleteAction.title"),
            message: action.title
        ) { [weak self] in
            self?.deleteActionAfterConfirmation(action)
        }
    }

    func confirmDestructiveAction(title: String, message: String, action: @escaping @MainActor () -> Void) {
        guard confirmsDestructiveActions else {
            action()
            return
        }

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text("confirm.destructive.confirm"))
        alert.addButton(withTitle: L10n.text("confirm.destructive.cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else {
            focusSearch()
            return
        }

        action()
    }

    private func deleteActionAfterConfirmation(_ action: CottageAction) {
        if let customAction = action.customAction {
            deleteCustomActionFolder(customAction)
            reloadActions()
            showsActionPalette = false
            selectedActionID = filteredActions.first?.id
            showStatus(L10n.text("status.deleted"))
            focusSearch()
            return
        }

        favoriteActionIDs.remove(action.id)
        hiddenActionIDs.insert(action.id)
        showsActionPalette = false
        saveSettings()
        selectedActionID = filteredActions.first?.id
        showStatus(L10n.text("status.deleted"))
        focusSearch()
    }

    private func deleteCustomActionFolder(_ customAction: CustomAction) {
        do {
            try FileManager.default.trashItem(at: customAction.directoryURL, resultingItemURL: nil)
        } catch {
            NSLog("CottagePanel cannot delete custom action folder: \(error.localizedDescription)")
        }
    }
}
