import AppKit
import SwiftUI

extension AppDelegate {
    func togglePanel() {
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        if shouldRestorePanelSession {
            state.prepareForPanelRestore()
        } else {
            state.reset()
        }
        lastPanelHiddenAt = nil
        let panel = makePanel()
        panel.setContentSize(NSSize(width: state.panelWidth, height: state.panelHeight))
        center(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        state.focusSearch()
    }

    func hidePanel() {
        lastPanelHiddenAt = Date()
        cancelCommandHints()
        state.showsActionPalette = false
        panel?.orderOut(nil)
    }

    func showSettings() {
        let window = makeSettingsWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private var shouldRestorePanelSession: Bool {
        guard let lastPanelHiddenAt else {
            return false
        }

        return state.restoresPanelSession
            && Date().timeIntervalSince(lastPanelHiddenAt) <= state.panelSessionRestoreSeconds
    }

    private func makePanel() -> CottagePanel {
        if let panel {
            return panel
        }

        let size = NSSize(width: state.panelWidth, height: state.panelHeight)
        let newPanel = CottagePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.backgroundColor = .clear
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.contentView = NSHostingView(rootView: ContentView(state: state))
        newPanel.hasShadow = true
        newPanel.isOpaque = false
        newPanel.level = .floating
        newPanel.isMovableByWindowBackground = true
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.standardWindowButton(.closeButton)?.isHidden = true
        newPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newPanel.standardWindowButton(.zoomButton)?.isHidden = true
        panel = newPanel
        return newPanel
    }

    private func makeSettingsWindow() -> NSWindow {
        if let settingsWindow {
            return settingsWindow
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: SettingsView(state: state))
        window.isReleasedWhenClosed = false
        window.title = L10n.text("settings.title")
        settingsWindow = window
        return window
    }

    private func center(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let frame = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.midY - panel.frame.height / 2
            )
        )
    }
}
