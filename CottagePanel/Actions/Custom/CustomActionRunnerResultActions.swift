import Foundation

extension CustomActionRunner {
    @MainActor
    static func executeMenuAction(_ menuAction: CustomMenuActionDefinition, in customAction: CustomAction) {
        let definition = CustomActionDefinition(
            id: menuAction.id,
            title: menuAction.title,
            subtitle: "",
            placeholder: nil,
            symbolName: menuAction.symbolName,
            tags: [],
            type: menuAction.type,
            command: menuAction.command,
            path: menuAction.path,
            url: menuAction.url,
            shortcutName: menuAction.shortcutName,
            presentation: .direct,
            trigger: .manual
        )
        executeDirect(CustomAction(definition: definition, directoryURL: customAction.directoryURL))
    }

    @MainActor
    @discardableResult
    static func executeResult(_ result: CustomActionResult) -> CustomResultExecutionStatus {
        if let url = result.url, openURL(url) {
            return .opened
        }

        if let path = result.path, openPath(path) {
            return .opened
        }

        if let command = result.command {
            let shellAction = CustomAction(
                definition: CustomActionDefinition.manualShell(command: command),
                directoryURL: FileManager.default.homeDirectoryForCurrentUser
            )
            executeDirect(shellAction)
            return .executed
        }

        copyToPasteboard(result.text.isEmpty ? result.title : result.text)
        return .copied
    }

    @MainActor
    @discardableResult
    static func executeResultAction(
        _ resultAction: CustomResultActionDefinition,
        result: CustomActionResult,
        in customAction: CustomAction?
    ) -> CustomResultExecutionStatus {
        let fieldValue = result.value(for: resultAction.field)
        if resultAction.operation == "copyResultText" {
            copyToPasteboard(result.text.isEmpty ? result.title : result.text)
            return .copied
        }
        if resultAction.operation == "revealInFinder",
           revealPath(fieldValue ?? result.path) {
            return .opened
        }

        switch resultAction.type {
        case .open, .openApp:
            if openPath(resultAction.path ?? fieldValue) {
                return .opened
            }
        case .url:
            if openURL(resultAction.url ?? fieldValue) {
                return .opened
            }
        case .shortcut, .script, .shell:
            executeResultProcess(resultAction, result: result, in: customAction)
            return .executed
        }

        copyToPasteboard(fieldValue ?? result.text)
        return .copied
    }

    @MainActor
    private static func executeResultProcess(
        _ resultAction: CustomResultActionDefinition,
        result: CustomActionResult,
        in customAction: CustomAction?
    ) {
        let definition = CustomActionDefinition(
            id: resultAction.id,
            title: resultAction.title,
            subtitle: "",
            placeholder: nil,
            symbolName: resultAction.symbolName,
            tags: [],
            type: resultAction.type,
            command: resultAction.command,
            path: resultAction.path,
            url: resultAction.url,
            shortcutName: resultAction.shortcutName,
            presentation: .direct,
            trigger: .manual
        )
        let action = CustomAction(
            definition: definition,
            directoryURL: customAction?.directoryURL ?? FileManager.default.homeDirectoryForCurrentUser
        )
        executeDirect(
            action,
            query: result.text,
            result: result,
            inputPayload: CustomActionInputPayload(
                apiVersion: customAction?.definition.apiVersion ?? 1,
                query: result.text,
                form: [:],
                accessory: [:],
                result: CustomActionResultInputPayload(result),
                navigation: nil
            )
        )
    }
}
