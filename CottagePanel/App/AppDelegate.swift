import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = CottageState()
    private var keyMonitor: Any?
    private var commandHintWorkItem: DispatchWorkItem?
    private var fallbackHotKey: CottageFallbackHotKey?
    var statusItem: NSStatusItem?
    var panel: CottagePanel?
    var settingsWindow: NSWindow?
    var lastPanelHiddenAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        state.hidePanel = { [weak self] in
            self?.hidePanel()
        }
        state.showSettings = { [weak self] in
            self?.showSettings()
        }
        state.quitApp = {
            NSApp.terminate(nil)
        }
        state.refreshMenuBar = { [weak self] in
            self?.refreshStatusMenu()
        }
        restoreDefaultShortcutIfNeeded()
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.togglePanel()
        }
        fallbackHotKey = CottageFallbackHotKey { [weak self] in
            self?.togglePanel()
        }
        installStatusItem()
        installKeyMonitor()
        if state.opensPanelOnLaunch {
            showPanel()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showSettingsFromCommand() {
        showPanel()
        state.openSettings()
    }

    private var isShortcutRecorderFocused: Bool {
        panel?.firstResponder is KeyboardShortcuts.RecorderCocoa
            || settingsWindow?.firstResponder is KeyboardShortcuts.RecorderCocoa
    }

    private func restoreDefaultShortcutIfNeeded() {
        guard KeyboardShortcuts.getShortcut(for: .togglePanel) == nil else {
            return
        }

        KeyboardShortcuts.reset(.togglePanel)
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.panel?.isVisible == true else {
                return event
            }

            if event.type == .flagsChanged {
                self.handleModifierChange(event)
                return event
            }

            if self.isShortcutRecorderFocused {
                return event
            }

            if self.handleShortcut(event) {
                return nil
            }

            if self.handleKeyboardOnly(event) {
                return nil
            }

            return self.handleBasePanelKey(event)
        }
    }

    private func handleBasePanelKey(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 36:
            state.runSelection()
            return nil
        case 53:
            state.handleEscape()
            return nil
        case 123:
            return state.adjustBuiltInSettingSelection(direction: .previous) ? nil : event
        case 124:
            return state.adjustBuiltInSettingSelection(direction: .next) ? nil : event
        case 125:
            state.moveSelection(.down)
            return nil
        case 126:
            state.moveSelection(.up)
            return nil
        default:
            return event
        }
    }

    private func handleShortcut(_ event: NSEvent) -> Bool {
        if shouldUseSystemTextEditing(for: event) {
            return false
        }

        if handleCopyShortcut(event) {
            return true
        }

        if matches(event, .showActionMenu) {
            cancelCommandHints()
            state.showActionsForSelection()
            return true
        }

        if event.keyCode == 53 {
            cancelCommandHints()
            return handleEscapeShortcut()
        }

        guard event.modifierFlags.contains(.command) else {
            return false
        }

        if let shortcutIndex = commandShortcutIndex(for: event) {
            cancelCommandHints()
            state.runCommandShortcut(index: shortcutIndex)
            return true
        }

        if let shortcut = CottageShortcut(event: event),
           state.runCustomMenuAction(matching: shortcut) {
            cancelCommandHints()
            return true
        }

        guard let actionID = secondaryActionID(for: event) else {
            return false
        }

        cancelCommandHints()
        state.runSecondaryAction(id: actionID)
        return true
    }

    private func matches(_ event: NSEvent, _ name: KeyboardShortcuts.Name) -> Bool {
        name.matches(event)
    }

    private func isCommandCopy(_ event: NSEvent) -> Bool {
        event.keyCode == 8
            && event.modifierFlags.contains(.command)
            && event.modifierFlags.isDisjoint(with: [.shift, .option, .control])
    }

    private func handleCopyShortcut(_ event: NSEvent) -> Bool {
        if state.showsCustomPopup,
           matches(event, .copySelectedResult) {
            state.copyPopupOutput()
            return true
        }

        guard state.activeCustomAction != nil else {
            return false
        }

        if matches(event, .copySelectedResult) || isCommandCopy(event) {
            state.copySelectedCustomResult()
            return true
        }
        return false
    }

    private func handleEscapeShortcut() -> Bool {
        if state.isActionMenuPresented {
            state.hideActionPalette()
            state.showsAppMenu = false
        } else {
            state.handleEscape()
        }
        return true
    }

    private func handleModifierChange(_ event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            scheduleCommandHints()
        } else {
            cancelCommandHints()
        }
    }

    func cancelCommandHints() {
        commandHintWorkItem?.cancel()
        commandHintWorkItem = nil
        state.setCommandActionHintsVisible(false)
    }

    private func scheduleCommandHints() {
        guard commandHintWorkItem == nil else {
            return
        }

        state.prepareCommandShortcutSnapshot()
        let workItem = DispatchWorkItem { [weak self] in
            self?.state.setCommandActionHintsVisible(true)
            self?.commandHintWorkItem = nil
        }
        commandHintWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

}

final class CottagePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
