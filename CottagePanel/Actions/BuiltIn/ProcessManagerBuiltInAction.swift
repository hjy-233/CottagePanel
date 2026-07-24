import AppKit
import Foundation

@MainActor
extension CottageState {
    func processManagerCottageAction() -> CottageAction {
        let customAction = processManagerCustomAction()
        return CottageAction(
            id: "built-in.processManager",
            title: L10n.text("action.processManager.title"),
            subtitle: L10n.text("action.processManager.subtitle"),
            symbolName: "cpu",
            kind: .command,
            icon: nil,
            fileURL: nil,
            customAction: customAction,
            tags: [
                "process",
                "pid",
                "activity",
                "monitor",
                "kill",
                L10n.text("tag.processManager")
            ]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }
}

private func processManagerCustomAction() -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: "built-in-process-manager",
            title: L10n.text("action.processManager.title"),
            subtitle: L10n.text("action.processManager.subtitle"),
            placeholder: L10n.text("action.processManager.placeholder"),
            symbolName: "cpu",
            tags: ["process", "pid", "activity", "monitor", "kill", L10n.text("tag.processManager")],
            type: .shell,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            resultActions: processManagerResultActions,
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.processManager.placeholder"),
                debounceMilliseconds: 250,
                allowsEmptyQuery: true
            )
        ),
        directoryURL: FileManager.default.homeDirectoryForCurrentUser
    )
}

private let processManagerResultActions = [
    CustomResultActionDefinition(
        id: "copy-pid",
        title: L10n.text("processManager.copyPID"),
        symbolName: "number",
        shortcut: "cmd+shift+c",
        type: .shell,
        command: "printf '%s' \"$COTTAGE_RESULT_TEXT\" | pbcopy"
    ),
    CustomResultActionDefinition(
        id: "copy-command",
        title: L10n.text("processManager.copyCommand"),
        symbolName: "doc.on.doc",
        shortcut: "cmd+shift+n",
        type: .shell,
        field: "subtitle",
        command: "printf '%s' \"$COTTAGE_RESULT_SUBTITLE\" | pbcopy"
    ),
    CustomResultActionDefinition(
        id: "quit-process",
        title: L10n.text("processManager.quit"),
        symbolName: "xmark.circle",
        shortcut: "cmd+shift+q",
        type: .shell,
        command: "/bin/kill -TERM \"$COTTAGE_RESULT_TEXT\"",
        confirm: CustomActionConfirmDefinition(
            enabled: true,
            title: L10n.text("processManager.quitConfirm"),
            message: nil
        )
    ),
    CustomResultActionDefinition(
        id: "force-quit-process",
        title: L10n.text("processManager.forceQuit"),
        symbolName: "xmark.octagon",
        shortcut: "cmd+shift+delete",
        type: .shell,
        command: "/bin/kill -KILL \"$COTTAGE_RESULT_TEXT\"",
        confirm: CustomActionConfirmDefinition(
            enabled: true,
            title: L10n.text("processManager.forceQuitConfirm"),
            message: nil
        )
    )
]

private let processManagerShellCommand = ""
