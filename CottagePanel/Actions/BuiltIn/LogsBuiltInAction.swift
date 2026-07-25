import Foundation

@MainActor
extension CottageState {
    func cottageLogsCottageAction() -> CottageAction {
        let customAction = cottageLogsCustomAction()
        return CottageAction(
            id: "built-in.cottageLogs",
            title: L10n.text("action.cottageLogs.title"),
            subtitle: L10n.text("action.cottageLogs.subtitle"),
            symbolName: "doc.text.magnifyingglass",
            kind: .command,
            icon: nil,
            fileURL: CottageLogStore.logsDirectory,
            customAction: customAction,
            tags: ["log", "logs", "debug", "stderr", "stdout", L10n.text("tag.cottageLogs")]
        ) { [weak self] in
            self?.runCustomAction(customAction)
        }
    }
}

private func cottageLogsCustomAction() -> CustomAction {
    CustomAction(
        definition: CustomActionDefinition(
            id: NativeBuiltInPanelActionID.cottageLogs.rawValue,
            title: L10n.text("action.cottageLogs.title"),
            subtitle: L10n.text("action.cottageLogs.subtitle"),
            placeholder: L10n.text("action.cottageLogs.placeholder"),
            symbolName: "doc.text.magnifyingglass",
            tags: ["log", "logs", "debug", "stderr", "stdout", L10n.text("tag.cottageLogs")],
            type: .shell,
            command: nil,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .panel,
            trigger: .live,
            input: CustomActionInputDefinition(
                placeholder: L10n.text("action.cottageLogs.placeholder"),
                debounceMilliseconds: 0,
                allowsEmptyQuery: true,
                acceptsDroppedText: false,
                acceptsDroppedFiles: false
            )
        ),
        directoryURL: CottageLogStore.logsDirectory
    )
}
