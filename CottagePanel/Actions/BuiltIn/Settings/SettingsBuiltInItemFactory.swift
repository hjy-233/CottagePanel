// 提供设置项结果的通用构造函数
extension CottageState {
    func toggleItem(
        id: String,
        titleKey: String,
        value: Bool,
        command: String,
        tags: [String]
    ) -> SettingsPanelItem {
        let valueText = value
            ? L10n.text("settings.panelAction.on")
            : L10n.text("settings.panelAction.off")
        return SettingsPanelItem(
            id: id,
            title: L10n.text(titleKey),
            subtitle: valueText,
            text: L10n.text("settings.panelAction.toggleHelp"),
            symbolName: value ? "checkmark.circle" : "circle",
            command: command,
            tags: tags,
            accessories: [
                CustomResultAccessory(
                    text: valueText,
                    symbolName: value ? "checkmark" : "xmark",
                    style: value ? "green" : "secondary"
                )
            ]
        )
    }

    func stepItem(id: String, title: String, command: String, tags: [String]) -> SettingsPanelItem {
        SettingsPanelItem(
            id: id,
            title: title,
            subtitle: L10n.text("settings.panelAction.cycleSubtitle"),
            text: L10n.text("settings.panelAction.cycleHelp"),
            symbolName: "slider.horizontal.3",
            command: command,
            tags: tags
        )
    }

    func cycleItem(
        id: String,
        titleKey: String,
        value: String,
        command: String,
        tags: [String]
    ) -> SettingsPanelItem {
        SettingsPanelItem(
            id: id,
            title: L10n.text(titleKey),
            subtitle: value,
            text: L10n.text("settings.panelAction.cycleHelp"),
            symbolName: "arrow.triangle.2.circlepath",
            command: command,
            tags: tags,
            accessories: [
                CustomResultAccessory(text: value, symbolName: nil, style: "blue")
            ]
        )
    }

    func actionItem(
        id: String,
        titleKey: String,
        subtitle: String,
        symbolName: String,
        command: String
    ) -> SettingsPanelItem {
        SettingsPanelItem(
            id: id,
            title: L10n.text(titleKey),
            subtitle: subtitle,
            text: subtitle,
            symbolName: symbolName,
            command: command,
            tags: [id, titleKey, command]
        )
    }
}
