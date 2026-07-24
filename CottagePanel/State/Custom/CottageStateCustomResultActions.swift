import AppKit
import Foundation

extension CottageState {
    func executeCustomResult(_ result: CustomActionResult) {
        showResultExecutionStatus(CustomActionRunner.executeResult(result))
    }

    func runCustomResultAction(_ resultAction: CustomResultActionDefinition, for result: CustomActionResult) {
        if let confirm = resultAction.confirm {
            confirmCustomAction(confirm, fallbackTitle: resultAction.title) { [weak self] in
                self?.runCustomResultActionAfterConfirmation(resultAction, for: result)
            }
            return
        }

        runCustomResultActionAfterConfirmation(resultAction, for: result)
    }

    func showCustomResultMenu(for result: CustomActionResult) {
        guard activeCustomAction?.definition.resultActions.isEmpty == false else {
            return
        }

        selectedCustomResultID = result.id
        shownCustomResultMenuID = result.id
        keyboardContext = .actionMenu
    }

    func runCustomResultAction(matching shortcut: CottageShortcut) -> Bool {
        guard let customAction = activeCustomAction,
              let result = selectedCustomResult,
              let resultAction = resultAction(
                  matching: shortcut,
                  in: customAction.definition.resultActions
              ) else {
            return false
        }

        runCustomResultAction(resultAction, for: result)
        return true
    }

    func showResultExecutionStatus(_ status: CustomResultExecutionStatus) {
        switch status {
        case .opened:
            showStatus(L10n.text("status.opened"))
        case .executed:
            showStatus(L10n.text("status.executed"))
        case .copied:
            showStatus(L10n.text("status.copied"))
        }
    }

    func confirmCustomAction(
        _ confirm: CustomActionConfirmDefinition,
        fallbackTitle: String,
        action: @escaping @MainActor () -> Void
    ) {
        guard confirm.enabled else {
            action()
            return
        }

        confirmDestructiveAction(
            title: confirm.title ?? fallbackTitle,
            message: confirm.message ?? fallbackTitle,
            action: action
        )
    }

    func applyPostRun(_ postRun: CustomActionPostRunDefinition) {
        guard let behavior = postRun.onSuccess else {
            return
        }

        switch behavior {
        case .keepPanel:
            focusSearch()
        case .closePanel:
            hideWindow()
        case .copyFirstResult:
            guard let firstResult = customResults.first else {
                return
            }

            copyText(firstResult.text.isEmpty ? firstResult.title : firstResult.text)
        case .copySelectedResult:
            copySelectedCustomResult()
        }
    }

    private func runCustomResultActionAfterConfirmation(
        _ resultAction: CustomResultActionDefinition,
        for result: CustomActionResult
    ) {
        showResultExecutionStatus(
            CustomActionRunner.executeResultAction(
                resultAction,
                result: result,
                in: activeCustomAction
            )
        )
        if let postRun = resultAction.postRun {
            applyPostRun(postRun)
        }
        shownCustomResultMenuID = nil
    }

    private func resultAction(
        matching shortcut: CottageShortcut,
        in actions: [CustomResultActionDefinition]
    ) -> CustomResultActionDefinition? {
        for action in actions {
            if CottageShortcut(action.shortcut) == shortcut {
                return action
            }
            if let child = resultAction(matching: shortcut, in: action.children) {
                return child
            }
        }
        return nil
    }
}
