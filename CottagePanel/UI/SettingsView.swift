// 已弃用设置界面
import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: CottageState

    var body: some View {
        Form {
            Section(L10n.text("settings.panel.section")) {
                Stepper(value: $state.panelWidth, in: 560...980, step: 20) {
                    Text(String(format: L10n.text("settings.panel.width"), Int(state.panelWidth)))
                }
                Stepper(value: $state.panelHeight, in: 360...720, step: 20) {
                    Text(String(format: L10n.text("settings.panel.height"), Int(state.panelHeight)))
                }
                Toggle(L10n.text("settings.showKeyboardHints"), isOn: $state.showsKeyboardHints)
                Toggle(L10n.text("settings.openPanelOnLaunch"), isOn: $state.opensPanelOnLaunch)
                Toggle(L10n.text("settings.confirmDestructiveActions"), isOn: $state.confirmsDestructiveActions)
                Toggle(L10n.text("settings.detailedLogs"), isOn: $state.detailedLogsEnabled)
                Toggle(L10n.text("settings.restorePanelSession"), isOn: $state.restoresPanelSession)
                Stepper(value: $state.panelSessionRestoreSeconds, in: 5...300, step: 5) {
                    Text(
                        String(
                            format: L10n.text("settings.restorePanelSeconds"),
                            Int(state.panelSessionRestoreSeconds)
                        )
                    )
                }
                .disabled(!state.restoresPanelSession)
                Picker(L10n.text("settings.language"), selection: $state.appLanguage) {
                    ForEach(CottageLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.togglePanelShortcut"),
                    name: .togglePanel
                )
            }

            Section(L10n.text("settings.config.section")) {
                Button(L10n.text("settings.openConfig")) {
                    state.openConfigDirectory()
                }
                Button(L10n.text("settings.openActions")) {
                    state.openActionsDirectory()
                }
                Button(L10n.text("settings.reloadActions")) {
                    state.reloadActionsFromUserAction()
                }
                Button(L10n.text("settings.importActions")) {
                    state.importActionsArchive()
                }
                Button(L10n.text("settings.exportActions")) {
                    state.exportActionsArchive()
                }
            }

            Section(L10n.text("settings.shortcuts.section")) {
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.showActionMenu"),
                    name: .showActionMenu
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.copySelectedResult"),
                    name: .copySelectedResult
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.focusPreview"),
                    name: .focusPreview
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.focusSearch"),
                    name: .focusSearch
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.showSelectionActions"),
                    name: .showSelectionActions
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.showNumberedActions"),
                    name: .showNumberedActions
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.favoriteAction"),
                    name: .favoriteAction
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.revealInFinder"),
                    name: .revealInFinder
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.copyName"),
                    name: .copyName
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.copyPath"),
                    name: .copyPath
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.quitApp"),
                    name: .quitApp
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.forceQuitApp"),
                    name: .forceQuitApp
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.restartApp"),
                    name: .restartApp
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.deleteAction"),
                    name: .deleteAction
                )
                KeyboardShortcuts.Recorder(
                    L10n.text("settings.shortcut.uninstallApp"),
                    name: .uninstallApp
                )
                Button(L10n.text("settings.shortcuts.reset")) {
                    KeyboardShortcuts.reset(KeyboardShortcuts.Name.panelShortcutNames)
                }
                Text(L10n.text("settings.shortcuts.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.text("settings.keyboard.section")) {
                Toggle(L10n.text("settings.keyboard.enabled"), isOn: $state.keyboardOnlyModeEnabled)
                Picker(L10n.text("settings.keyboard.panelNavigation"), selection: $state.panelNavigationScheme) {
                    ForEach(CottageKeyboardNavigationScheme.allCases) { scheme in
                        Text(scheme.title).tag(scheme)
                    }
                }
                Picker(L10n.text("settings.keyboard.menuNavigation"), selection: $state.menuNavigationScheme) {
                    ForEach(CottageKeyboardNavigationScheme.allCases) { scheme in
                        Text(scheme.title).tag(scheme)
                    }
                }
                Picker(L10n.text("settings.keyboard.previewScroll"), selection: $state.previewScrollScheme) {
                    ForEach(CottagePreviewScrollScheme.allCases) { scheme in
                        Text(scheme.title).tag(scheme)
                    }
                }
                Text(L10n.text("settings.keyboard.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 560, height: 640)
    }
}
