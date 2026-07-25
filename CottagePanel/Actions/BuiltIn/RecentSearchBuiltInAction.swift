import Foundation

@MainActor
extension CottageState {
    func recentSearchCottageAction() -> CottageAction {
        let customAction = recentSearchCustomAction()
        return CottageAction(
            id: "built-in.recentSearch",
            title: L10n.text("action.recentSearch.title"),
            subtitle: L10n.text("action.recentSearch.subtitle"),
            symbolName: "clock.arrow.circlepath",
            kind: .command,
            icon: nil,
            fileURL: nil,
            customAction: customAction,
            tags: ["recent", "search", "history", "restore", L10n.text("tag.recentSearch")]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }
}

private func recentSearchCustomAction() -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: NativeBuiltInPanelActionID.recentSearch.rawValue,
            title: L10n.text("action.recentSearch.title"),
            subtitle: L10n.text("action.recentSearch.subtitle"),
            placeholder: L10n.text("action.recentSearch.placeholder"),
            symbolName: "clock.arrow.circlepath",
            tags: ["recent", "search", "history", "restore", L10n.text("tag.recentSearch")],
            type: .shell,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.recentSearch.placeholder"),
                debounceMilliseconds: 0,
                allowsEmptyQuery: true,
                acceptsDroppedText: false,
                acceptsDroppedFiles: false
            )
        ),
        directoryURL: FileManager.default.homeDirectoryForCurrentUser
    )
}
