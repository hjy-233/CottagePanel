import AppKit
import Foundation

@MainActor
extension CottageState {
    func translatorCottageAction() -> CottageAction {
        let customAction = translatorCustomAction()
        return CottageAction(
            id: "built-in.translator",
            title: L10n.text("action.translator.title"),
            subtitle: L10n.text("action.translator.subtitle"),
            symbolName: "character.book.closed",
            kind: .command,
            icon: nil,
            fileURL: nil,
            customAction: customAction,
            tags: ["translate", "translator", "language", "text", L10n.text("tag.translator")]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }
}

private func translatorCustomAction() -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: "built-in-translator",
            title: L10n.text("action.translator.title"),
            subtitle: L10n.text("action.translator.subtitle"),
            placeholder: L10n.text("action.translator.placeholder"),
            symbolName: "character.bubble",
            tags: ["translate", "translator", "language", "text", L10n.text("tag.translator")],
            type: .shell,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .manual,
            resultActions: translatorResultActions,
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.translator.placeholder"),
                debounceMilliseconds: 450,
                allowsEmptyQuery: false
            ),
            searchAccessory: CustomSearchAccessoryDefinition(
                id: "target",
                envKey: "target_language",
                defaultValue: "zh-CN",
                items: translatorLanguages
            )
        ),
        directoryURL: FileManager.default.homeDirectoryForCurrentUser
    )
}

private let translatorLanguages = [
    CustomPickerItemDefinition(id: "zh-CN", title: "中文"),
    CustomPickerItemDefinition(id: "en", title: "English"),
    CustomPickerItemDefinition(id: "ja", title: "日本語"),
    CustomPickerItemDefinition(id: "ko", title: "한국어"),
    CustomPickerItemDefinition(id: "fr", title: "Français"),
    CustomPickerItemDefinition(id: "de", title: "Deutsch"),
    CustomPickerItemDefinition(id: "es", title: "Español"),
    CustomPickerItemDefinition(id: "ru", title: "Русский")
]

private let translatorResultActions = [
    CustomResultActionDefinition(
        id: "copy-translation",
        title: L10n.text("translator.copyTranslation"),
        symbolName: "doc.on.doc",
        shortcut: "cmd+shift+c",
        type: .shell,
        command: "printf '%s' \"$COTTAGE_RESULT_TEXT\" | pbcopy"
    ),
    CustomResultActionDefinition(
        id: "copy-source",
        title: L10n.text("translator.copySource"),
        symbolName: "text.quote",
        shortcut: "cmd+shift+s",
        type: .shell,
        field: "subtitle",
        command: "printf '%s' \"$COTTAGE_RESULT_SUBTITLE\" | pbcopy"
    )
]

private let translatorShellCommand = ""
