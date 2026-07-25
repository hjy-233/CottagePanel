import AppKit
import Foundation

@MainActor
extension CottageState {
    func calculateCottageAction() -> CottageAction {
        let customAction = calculateCustomAction()
        return CottageAction(
            id: "built-in.calculator",
            title: L10n.text("action.calculate.title"),
            subtitle: L10n.text("action.calculate.subtitle"),
            symbolName: "function",
            kind: .command,
            icon: nil,
            fileURL: calculateScriptDirectoryURL(),
            customAction: customAction,
            tags: [
                "calculate",
                "calculator",
                "math",
                "eval",
                "unit",
                "currency",
                "timezone",
                "date",
                "计算",
                "jisuan",
                L10n.text("tag.calculate")
            ]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }
}

private func calculateCustomAction() -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: "built-in-calculate",
            title: L10n.text("action.calculate.title"),
            subtitle: L10n.text("action.calculate.subtitle"),
            placeholder: L10n.text("action.calculate.placeholder"),
            symbolName: "function",
            tags: [
                "calculate",
                "calculator",
                "math",
                "eval",
                "unit",
                "currency",
                "timezone",
                "date",
                "计算",
                "jisuan",
                L10n.text("tag.calculate")
            ],
            type: .script,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            menuActions: [copyPiMenuAction()],
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.calculate.placeholder"),
                debounceMilliseconds: 0,
                allowsEmptyQuery: false
            )
        ),
        directoryURL: calculateScriptDirectoryURL()
    )
}

private func copyPiMenuAction() -> CustomMenuActionDefinition {
    CustomMenuActionDefinition(
        id: "copy-pi",
        title: L10n.text("action.calculate.copyPi"),
        symbolName: "doc.on.doc",
        shortcut: "cmd+shift+p",
        type: .shell,
        command: "printf '3.141592653589793' | pbcopy",
        path: nil,
        url: nil,
        shortcutName: nil
    )
}

private func calculateScriptDirectoryURL() -> URL {
    if let url = Bundle.main.url(
        forResource: "calculate-run",
        withExtension: "py"
    )?.deletingLastPathComponent() {
        return url
    }

    return URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Calculate")
}
