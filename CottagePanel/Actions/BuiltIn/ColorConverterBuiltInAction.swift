import AppKit
import Foundation

@MainActor
extension CottageState {
    func colorConverterCottageAction() -> CottageAction {
        let customAction = colorConverterCustomAction()
        return CottageAction(
            id: "built-in.colorConverter",
            title: L10n.text("action.colorConverter.title"),
            subtitle: L10n.text("action.colorConverter.subtitle"),
            symbolName: "paintpalette",
            kind: .command,
            icon: nil,
            fileURL: nil,
            customAction: customAction,
            tags: [
                "color",
                "colour",
                "converter",
                "hex",
                "rgb",
                "hsl",
                "颜色",
                "yanse",
                L10n.text("tag.colorConverter")
            ]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }
}

private func colorConverterCustomAction() -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: "built-in-color-converter",
            title: L10n.text("action.colorConverter.title"),
            subtitle: L10n.text("action.colorConverter.subtitle"),
            placeholder: L10n.text("action.colorConverter.placeholder"),
            symbolName: "paintpalette",
            tags: [
                "color",
                "colour",
                "converter",
                "hex",
                "rgb",
                "hsl",
                "颜色",
                "yanse",
                L10n.text("tag.colorConverter")
            ],
            type: .shell,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            resultActions: [copyHexColorAction(), copyRGBColorAction()],
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.colorConverter.placeholder"),
                debounceMilliseconds: 120,
                allowsEmptyQuery: false
            )
        ),
        directoryURL: FileManager.default.homeDirectoryForCurrentUser
    )
}

private func copyHexColorAction() -> CustomResultActionDefinition {
    CustomResultActionDefinition(
        id: "copy-hex",
        title: L10n.text("colorConverter.copyHex"),
        symbolName: "number",
        shortcut: "cmd+shift+h",
        type: .shell,
        command: "printf '%s' \"$COTTAGE_RESULT_TITLE\" | pbcopy",
        path: nil,
        url: nil,
        shortcutName: nil
    )
}

private func copyRGBColorAction() -> CustomResultActionDefinition {
    CustomResultActionDefinition(
        id: "copy-rgb",
        title: L10n.text("colorConverter.copyRGB"),
        symbolName: "doc.on.doc",
        shortcut: "cmd+shift+r",
        type: .shell,
        command: "printf '%s' \"$COTTAGE_RESULT_SUBTITLE\" | pbcopy",
        path: nil,
        url: nil,
        shortcutName: nil
    )
}

private let colorConverterShellCommand = ""
