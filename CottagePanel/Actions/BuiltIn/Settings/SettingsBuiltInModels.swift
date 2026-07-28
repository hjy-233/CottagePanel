// 定义设置面板中的列表项和快捷键项模型
import KeyboardShortcuts

struct SettingsPanelItem {
    let id: String
    let title: String
    let subtitle: String
    let text: String
    let symbolName: String
    let command: String
    var presentation: CustomActionPresentation?
    let tags: [String]
    var accessories: [CustomResultAccessory] = []
    var metadata: [CustomResultMetadata] = []

    var result: CustomActionResult {
        CustomActionResult(
            id: id,
            title: title,
            subtitle: subtitle,
            text: text,
            tags: tags,
            url: nil,
            path: nil,
            previewImagePath: nil,
            command: command,
            presentation: presentation,
            navigationCommand: nil,
            navigation: nil,
            accessories: accessories,
            metadata: metadata,
            isError: false
        )
    }

    func matches(_ query: String, initials: String, allowsFuzzy: Bool = false) -> Bool {
        let exactMatch = title.localizedCaseInsensitiveContains(query)
            || subtitle.localizedCaseInsensitiveContains(query)
            || text.localizedCaseInsensitiveContains(query)
            || tags.contains { $0.localizedCaseInsensitiveContains(query) }
            || (!initials.isEmpty && searchInitials(from: title).hasPrefix(initials))
        guard !exactMatch, allowsFuzzy else {
            return exactMatch
        }

        return fuzzySearchMatches(query, in: [title, subtitle, text] + tags)
    }
}

struct SettingsShortcutItem {
    let id: String
    let title: String
    let name: KeyboardShortcuts.Name
}

enum SettingsCategory: String, CaseIterable {
    case panel
    case actions
    case shortcuts
    case keyboard
    case security

    var id: String { rawValue }

    var title: String {
        switch self {
        case .panel:
            L10n.text("settings.panel.section")
        case .actions:
            L10n.text("settings.config.section")
        case .shortcuts:
            L10n.text("settings.shortcuts.section")
        case .keyboard:
            L10n.text("settings.keyboard.section")
        case .security:
            L10n.text("settings.security.section")
        }
    }

    var subtitle: String {
        switch self {
        case .panel:
            L10n.text("settings.panelAction.panel.subtitle")
        case .actions:
            L10n.text("settings.panelAction.actions.subtitle")
        case .shortcuts:
            L10n.text("settings.panelAction.shortcuts.subtitle")
        case .keyboard:
            L10n.text("settings.panelAction.keyboard.subtitle")
        case .security:
            L10n.text("settings.panelAction.security.subtitle")
        }
    }

    var text: String {
        subtitle
    }

    var symbolName: String {
        switch self {
        case .panel:
            "rectangle.inset.filled"
        case .actions:
            "shippingbox"
        case .shortcuts:
            "keyboard"
        case .keyboard:
            "command"
        case .security:
            "lock.shield"
        }
    }

    var tags: [String] {
        [id, title, subtitle]
    }
}
