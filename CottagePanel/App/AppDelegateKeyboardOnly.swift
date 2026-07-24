import AppKit
import KeyboardShortcuts

extension AppDelegate {
    func handleKeyboardOnly(_ event: NSEvent) -> Bool {
        guard state.keyboardOnlyModeEnabled else {
            return false
        }
        if handleQuestionNumberPrefix(event) || handleActionMenuKeyboard(event) {
            return true
        }
        if handleQuestionKey(event) || handleContextKey(event) || handlePreviewKeyboard(event) {
            return true
        }
        if state.keyboardContext == .search, state.panelNavigationScheme != .arrows {
            return false
        }
        return handlePanelNavigation(event)
    }

    private func handleQuestionNumberPrefix(_ event: NSEvent) -> Bool {
        guard state.showsQuestionNumberPrefix else {
            return false
        }
        guard let shortcutIndex = commandShortcutIndex(for: event) else {
            state.cancelQuestionNumberPrefix()
            return false
        }
        state.showMenuForCommandShortcut(index: shortcutIndex)
        return true
    }

    private func handleActionMenuKeyboard(_ event: NSEvent) -> Bool {
        guard state.isActionMenuPresented else {
            return false
        }
        if event.keyCode == 36 {
            postMenuCommand(.enter)
            return true
        }
        if event.keyCode == 53 {
            postMenuCommand(.escape)
            state.hideActionPalette()
            state.showsAppMenu = false
            return true
        }
        if event.keyCode == 51 {
            postMenuCommand(.backspace)
            return true
        }
        return handleMenuNavigation(event)
    }

    private func handleQuestionKey(_ event: NSEvent) -> Bool {
        if event.matches(.showNumberedActions) {
            cancelCommandHints()
            state.enterQuestionNumberPrefix()
            return true
        }
        if event.matches(.showSelectionActions) {
            cancelCommandHints()
            state.showActionsForSelection()
            return true
        }
        return false
    }

    private func handleContextKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 48 {
            state.cycleKeyboardContext(reverse: event.modifierFlags.contains(.shift))
            return true
        }
        if event.matches(.focusPreview) {
            state.keyboardContext = .preview
            state.focusSearch()
            return true
        }
        if event.matches(.focusSearch), state.keyboardContext != .search {
            state.keyboardContext = .search
            state.focusSearch()
            return true
        }
        return false
    }

    private func handlePanelNavigation(_ event: NSEvent) -> Bool {
        guard let direction = keyboardDirection(for: event, scheme: state.panelNavigationScheme) else {
            return false
        }
        switch direction {
        case .moveUp:
            state.moveSelection(.up)
        case .moveDown:
            state.moveSelection(.down)
        case .moveLeft:
            if state.adjustBuiltInSettingSelection(direction: .previous) {
                return true
            }
            state.moveKeyboardContext(direction)
        case .moveRight:
            if state.adjustBuiltInSettingSelection(direction: .next) {
                return true
            }
            state.moveKeyboardContext(direction)
        }
        return true
    }

    private func handleMenuNavigation(_ event: NSEvent) -> Bool {
        guard let direction = keyboardDirection(for: event, scheme: state.menuNavigationScheme) else {
            return false
        }
        switch direction {
        case .moveUp:
            postMenuCommand(.moveUp)
        case .moveDown:
            postMenuCommand(.moveDown)
        case .moveLeft:
            postMenuCommand(.moveLeft)
        case .moveRight:
            postMenuCommand(.moveRight)
        }
        return true
    }

    private func handlePreviewKeyboard(_ event: NSEvent) -> Bool {
        guard state.keyboardContext == .preview else {
            return false
        }
        let supportsJK = state.previewScrollScheme != .pageKeys
        let supportsPage = state.previewScrollScheme != .letterKeys
        if supportsJK, event.keyCode == 38 {
            postPreviewCommand(.scrollDown)
            return true
        }
        if supportsJK, event.keyCode == 40 {
            postPreviewCommand(.scrollUp)
            return true
        }
        if supportsPage, event.keyCode == 121 {
            postPreviewCommand(.scrollDown)
            return true
        }
        if supportsPage, event.keyCode == 116 {
            postPreviewCommand(.scrollUp)
            return true
        }
        return false
    }

    private func keyboardDirection(
        for event: NSEvent,
        scheme: CottageKeyboardNavigationScheme
    ) -> CottageKeyboardDirection? {
        guard event.modifierFlags.isDisjoint(with: [.command, .option, .control]) else {
            return nil
        }
        switch (scheme, event.keyCode) {
        case (.arrows, 126), (.wasd, 13), (.hjkl, 40):
            return .moveUp
        case (.arrows, 125), (.wasd, 1), (.hjkl, 38):
            return .moveDown
        case (.arrows, 123), (.wasd, 0), (.hjkl, 4):
            return .moveLeft
        case (.arrows, 124), (.wasd, 2), (.hjkl, 37):
            return .moveRight
        default:
            return nil
        }
    }

    private func postMenuCommand(_ command: CottageMenuKeyboardCommand) {
        NotificationCenter.default.post(name: .cottageMenuKeyboardCommand, object: command)
    }

    private func postPreviewCommand(_ command: CottagePreviewScrollCommand) {
        NotificationCenter.default.post(name: .cottagePreviewScrollCommand, object: command)
    }
}

private extension NSEvent {
    func matches(_ name: KeyboardShortcuts.Name) -> Bool {
        name.matches(self)
    }
}
