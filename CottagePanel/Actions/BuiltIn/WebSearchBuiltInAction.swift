import AppKit
import Foundation

@MainActor
extension CottageState {
    func webSearchCottageAction() -> CottageAction {
        let customAction = webSearchCustomAction()
        return CottageAction(
            id: "built-in.webSearch",
            title: L10n.text("action.webSearch.title"),
            subtitle: L10n.text("action.webSearch.subtitle"),
            symbolName: "globe",
            kind: .command,
            icon: nil,
            fileURL: nil,
            customAction: customAction,
            tags: [
                "web",
                "search",
                "url",
                "google",
                "duckduckgo",
                "bing",
                L10n.text("tag.webSearch")
            ]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }
}

private func webSearchCustomAction() -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: "built-in-web-search",
            title: L10n.text("action.webSearch.title"),
            subtitle: L10n.text("action.webSearch.subtitle"),
            placeholder: L10n.text("action.webSearch.placeholder"),
            symbolName: "globe",
            tags: ["web", "search", "url", "google", "duckduckgo", "bing", L10n.text("tag.webSearch")],
            type: .shell,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.webSearch.placeholder"),
                debounceMilliseconds: 120,
                allowsEmptyQuery: false
            ),
            searchAccessory: CustomSearchAccessoryDefinition(
                id: "engine",
                envKey: "search_engine",
                defaultValue: "google",
                items: webSearchEngines
            )
        ),
        directoryURL: FileManager.default.homeDirectoryForCurrentUser
    )
}

private let webSearchEngines = [
    CustomPickerItemDefinition(id: "google", title: "Google"),
    CustomPickerItemDefinition(id: "duckduckgo", title: "DuckDuckGo"),
    CustomPickerItemDefinition(id: "bing", title: "Bing"),
    CustomPickerItemDefinition(id: "brave", title: "Brave"),
    CustomPickerItemDefinition(id: "github", title: "GitHub"),
    CustomPickerItemDefinition(id: "wikipedia", title: "Wikipedia")
]

private let webSearchShellCommand = ""
