// 处理设置内导入导出 actions 的表单流程
extension CottageState {
    func runBuiltInSettingsExportResultIfNeeded(_ result: CustomActionResult) -> Bool {
        guard isBuiltInSettingsExportPanelActive,
              let command = result.command else {
            return false
        }

        if command.hasPrefix("cottage-settings:export-toggle:") {
            toggleExportItem(command: command)
            refreshBuiltInSettingsResults()
            return true
        }

        switch command {
        case "cottage-settings:export-continue":
            confirmActionsExport()
        case "cottage-settings:export-cancel":
            _ = popCustomNavigationStack()
        default:
            return false
        }
        return true
    }

    func exportPanelResults(query: String) -> [CustomActionResult] {
        let items = exportPanelItems()
        let trimmedQuery = query.trimmedSearchText
        guard !trimmedQuery.isEmpty else {
            return items.map(\.result)
        }

        let initials = normalizedSearchText(trimmedQuery)
        return items
            .filter { $0.matches(trimmedQuery, initials: initials, allowsFuzzy: fuzzySearchEnabled) }
            .map(\.result)
    }
}

private extension CottageState {
    func exportPanelItems() -> [SettingsPanelItem] {
        exportActionItems.map(exportItem) + exportControlItems()
    }

    func exportItem(_ item: ActionExportItem) -> SettingsPanelItem {
        let selectedText = item.isSelected
            ? L10n.text("actions.export.panel.selected")
            : L10n.text("actions.export.panel.notSelected")
        return SettingsPanelItem(
            id: "export.\(item.folder.url.lastPathComponent)",
            title: item.folder.title,
            subtitle: item.folder.url.lastPathComponent,
            text: item.folder.url.path,
            symbolName: item.isSelected ? "checkmark.square" : "square",
            command: "cottage-settings:export-toggle:\(item.folder.url.path)",
            tags: ["export", "action", item.folder.title, item.folder.url.lastPathComponent],
            accessories: [
                CustomResultAccessory(
                    text: selectedText,
                    symbolName: item.isSelected ? "checkmark" : nil,
                    style: item.isSelected ? "green" : "secondary"
                )
            ],
            metadata: [
                CustomResultMetadata(
                    label: L10n.text("settings.panelAction.metadata.current"),
                    value: selectedText,
                    type: nil,
                    url: nil
                ),
                CustomResultMetadata(
                    label: L10n.text("trustAction.summary.path"),
                    value: item.folder.url.path,
                    type: "code",
                    url: nil
                )
            ]
        )
    }

    func exportControlItems() -> [SettingsPanelItem] {
        [
            SettingsPanelItem(
                id: "export.continue",
                title: L10n.text("actions.export.continue"),
                subtitle: selectedExportCountText,
                text: L10n.text("actions.export.message"),
                symbolName: "square.and.arrow.up",
                command: "cottage-settings:export-continue",
                tags: ["export", "continue", "save"]
            ),
            SettingsPanelItem(
                id: "export.cancel",
                title: L10n.text("actions.export.cancel"),
                subtitle: L10n.text("settings.panelAction.backSubtitle"),
                text: L10n.text("settings.panelAction.backHelp"),
                symbolName: "xmark.circle",
                command: "cottage-settings:export-cancel",
                tags: ["export", "cancel"]
            )
        ]
    }

    var selectedExportCountText: String {
        String(
            format: L10n.text("actions.export.panel.selectedCount"),
            exportActionItems.filter(\.isSelected).count,
            exportActionItems.count
        )
    }

    func toggleExportItem(command: String) {
        let path = String(command.dropFirst("cottage-settings:export-toggle:".count))
        guard let index = exportActionItems.firstIndex(where: { $0.folder.url.path == path }) else {
            return
        }

        exportActionItems[index].isSelected.toggle()
    }
}
