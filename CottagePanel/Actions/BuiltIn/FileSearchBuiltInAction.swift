import AppKit
import Foundation

@MainActor
extension CottageState {
    func fileSearchCottageAction() -> CottageAction {
        let customAction = fileSearchCustomAction()
        return CottageAction(
            id: "built-in.fileSearch",
            title: L10n.text("action.fileSearch.title"),
            subtitle: L10n.text("action.fileSearch.subtitle"),
            symbolName: "magnifyingglass",
            kind: .command,
            icon: nil,
            fileURL: nil,
            customAction: customAction,
            tags: [
                "file",
                "files",
                "finder",
                "search",
                "spotlight",
                L10n.text("tag.fileSearch")
            ]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }
}

private func fileSearchCustomAction() -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: "built-in-file-search",
            title: L10n.text("action.fileSearch.title"),
            subtitle: L10n.text("action.fileSearch.subtitle"),
            placeholder: L10n.text("action.fileSearch.placeholder"),
            symbolName: "magnifyingglass",
            tags: [
                "file",
                "files",
                "finder",
                "search",
                "spotlight",
                L10n.text("tag.fileSearch")
            ],
            type: .shell,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            resultActions: [revealFileSearchResultAction()],
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.fileSearch.placeholder"),
                debounceMilliseconds: 250,
                allowsEmptyQuery: false
            ),
            searchAccessory: CustomSearchAccessoryDefinition(
                id: "scope",
                envKey: "file_search_scope",
                defaultValue: "mac",
                items: [
                    CustomPickerItemDefinition(id: "mac", title: L10n.text("fileSearch.scope.myMac")),
                    CustomPickerItemDefinition(id: "home", title: L10n.text("fileSearch.scope.home")),
                    CustomPickerItemDefinition(id: "desktop", title: L10n.text("fileSearch.scope.desktop")),
                    CustomPickerItemDefinition(id: "downloads", title: L10n.text("fileSearch.scope.downloads")),
                    CustomPickerItemDefinition(id: "documents", title: L10n.text("fileSearch.scope.documents")),
                    CustomPickerItemDefinition(id: "applications", title: L10n.text("fileSearch.scope.applications"))
                ]
            )
        ),
        directoryURL: FileManager.default.homeDirectoryForCurrentUser
    )
}

private func revealFileSearchResultAction() -> CustomResultActionDefinition {
    CustomResultActionDefinition(
        id: "reveal-in-finder",
        title: L10n.text("fileSearch.revealInFinder"),
        symbolName: "folder",
        shortcut: "cmd+o",
        type: .open,
        field: "path",
        command: nil,
        operation: "revealInFinder"
    )
}

private let fileSearchShellCommand = ""
