// 定义 action.json 的核心协议模型
import Foundation

// MARK: - Core Enums

enum CustomActionType: String, Codable {
    case script
    case openApp
    case shortcut
    case url
    case open
    case shell
}

enum CustomActionPresentation: String, Codable {
    case direct
    case panel
    case popup
    case form
}

enum CustomActionTrigger: String, Codable {
    case manual
    case live
}

enum CustomActionPreviewStyle: String, Codable {
    case text
    case json
    case markdown
}

enum CustomActionPostRunBehavior: String, Codable {
    case keepPanel
    case closePanel
    case copyFirstResult
    case copySelectedResult
}

// MARK: - Action Definition

struct CustomActionDefinition: Codable, Hashable {
    let apiVersion: Int
    let id: String
    let title: String
    let subtitle: String
    let placeholder: String?
    let symbolName: String?
    let icon: String?
    let tags: [String]
    let type: CustomActionType
    let command: String?
    let path: String?
    let url: String?
    let shortcutName: String?
    let presentation: CustomActionPresentation
    let trigger: CustomActionTrigger
    let menuActions: [CustomMenuActionDefinition]
    let resultActions: [CustomResultActionDefinition]
    let shortcuts: [CustomMenuActionDefinition]
    let preview: CustomActionPreviewDefinition
    let input: CustomActionInputDefinition
    let confirm: CustomActionConfirmDefinition?
    let postRun: CustomActionPostRunDefinition
    let searchAccessory: CustomSearchAccessoryDefinition?
    let form: CustomFormDefinition?
    let menuBar: CustomMenuBarDefinition?

    var actionMenuActions: [CustomMenuActionDefinition] {
        menuActions + shortcuts
    }

    var searchPlaceholder: String {
        input.placeholder
            ?? placeholder
            ?? (subtitle.isEmpty ? nil : subtitle)
            ?? title
    }

    init(
        id: String,
        title: String,
        subtitle: String,
        placeholder: String?,
        symbolName: String?,
        icon: String? = nil,
        tags: [String],
        type: CustomActionType,
        command: String?,
        path: String?,
        url: String?,
        shortcutName: String?,
        presentation: CustomActionPresentation,
        trigger: CustomActionTrigger,
        menuActions: [CustomMenuActionDefinition] = [],
        resultActions: [CustomResultActionDefinition] = [],
        shortcuts: [CustomMenuActionDefinition] = [],
        preview: CustomActionPreviewDefinition = CustomActionPreviewDefinition(),
        input: CustomActionInputDefinition = CustomActionInputDefinition(),
        confirm: CustomActionConfirmDefinition? = nil,
        postRun: CustomActionPostRunDefinition = CustomActionPostRunDefinition(),
        searchAccessory: CustomSearchAccessoryDefinition? = nil,
        form: CustomFormDefinition? = nil,
        menuBar: CustomMenuBarDefinition? = nil
    ) {
        self.apiVersion = 1
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.placeholder = placeholder
        self.symbolName = symbolName
        self.icon = icon
        self.tags = tags
        self.type = type
        self.command = command
        self.path = path
        self.url = url
        self.shortcutName = shortcutName
        self.presentation = presentation
        self.trigger = trigger
        self.menuActions = menuActions
        self.resultActions = resultActions
        self.shortcuts = shortcuts
        self.preview = preview
        self.input = input
        self.confirm = confirm
        self.postRun = postRun
        self.searchAccessory = searchAccessory
        self.form = form
        self.menuBar = menuBar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiVersion = try container.decodeIfPresent(Int.self, forKey: .apiVersion) ?? 1
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        type = try container.decode(CustomActionType.self, forKey: .type)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        shortcutName = try container.decodeIfPresent(String.self, forKey: .shortcutName)
        presentation = try container.decodeIfPresent(CustomActionPresentation.self, forKey: .presentation) ?? .direct
        trigger = try container.decodeIfPresent(CustomActionTrigger.self, forKey: .trigger) ?? .manual
        menuActions = try container.decodeIfPresent([CustomMenuActionDefinition].self, forKey: .menuActions) ?? []
        resultActions = try container.decodeIfPresent([CustomResultActionDefinition].self, forKey: .resultActions) ?? []
        shortcuts = try container.decodeIfPresent([CustomMenuActionDefinition].self, forKey: .shortcuts) ?? []
        preview = try container.decodeIfPresent(CustomActionPreviewDefinition.self, forKey: .preview)
            ?? CustomActionPreviewDefinition()
        input = try container.decodeIfPresent(CustomActionInputDefinition.self, forKey: .input)
            ?? CustomActionInputDefinition()
        confirm = try container.decodeIfPresent(CustomActionConfirmDefinition.self, forKey: .confirm)
        postRun = try container.decodeIfPresent(CustomActionPostRunDefinition.self, forKey: .postRun)
            ?? CustomActionPostRunDefinition()
        searchAccessory = try container.decodeIfPresent(CustomSearchAccessoryDefinition.self, forKey: .searchAccessory)
        form = try container.decodeIfPresent(CustomFormDefinition.self, forKey: .form)
        menuBar = try container.decodeIfPresent(CustomMenuBarDefinition.self, forKey: .menuBar)
    }
}

// MARK: - Menu and Result Actions

struct CustomMenuActionDefinition: Codable, Hashable {
    let id: String
    let title: String
    let symbolName: String?
    let shortcut: String?
    let type: CustomActionType
    let command: String?
    let operation: String?
    let path: String?
    let url: String?
    let shortcutName: String?
    let confirm: CustomActionConfirmDefinition?
    let postRun: CustomActionPostRunDefinition?
    let children: [CustomMenuActionDefinition]

    init(
        id: String,
        title: String,
        symbolName: String?,
        shortcut: String?,
        type: CustomActionType,
        command: String?,
        operation: String? = nil,
        path: String?,
        url: String?,
        shortcutName: String?,
        confirm: CustomActionConfirmDefinition? = nil,
        postRun: CustomActionPostRunDefinition? = nil,
        children: [CustomMenuActionDefinition] = []
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.shortcut = shortcut
        self.type = type
        self.command = command
        self.operation = operation
        self.path = path
        self.url = url
        self.shortcutName = shortcutName
        self.confirm = confirm
        self.postRun = postRun
        self.children = children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName)
        shortcut = try container.decodeIfPresent(String.self, forKey: .shortcut)
        type = try container.decodeIfPresent(CustomActionType.self, forKey: .type) ?? .shell
        command = try container.decodeIfPresent(String.self, forKey: .command)
        operation = try container.decodeIfPresent(String.self, forKey: .operation)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        shortcutName = try container.decodeIfPresent(String.self, forKey: .shortcutName)
        confirm = try container.decodeIfPresent(CustomActionConfirmDefinition.self, forKey: .confirm)
        postRun = try container.decodeIfPresent(CustomActionPostRunDefinition.self, forKey: .postRun)
        children = try container.decodeIfPresent([CustomMenuActionDefinition].self, forKey: .children) ?? []
    }
}

struct CustomResultActionDefinition: Codable, Hashable {
    let id: String
    let title: String
    let symbolName: String?
    let shortcut: String?
    let type: CustomActionType
    let field: String?
    let command: String?
    let operation: String?
    let path: String?
    let url: String?
    let shortcutName: String?
    let confirm: CustomActionConfirmDefinition?
    let postRun: CustomActionPostRunDefinition?
    let children: [CustomResultActionDefinition]

    init(
        id: String,
        title: String,
        symbolName: String?,
        shortcut: String?,
        type: CustomActionType,
        field: String? = nil,
        command: String?,
        operation: String? = nil,
        path: String? = nil,
        url: String? = nil,
        shortcutName: String? = nil,
        confirm: CustomActionConfirmDefinition? = nil,
        postRun: CustomActionPostRunDefinition? = nil,
        children: [CustomResultActionDefinition] = []
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.shortcut = shortcut
        self.type = type
        self.field = field
        self.command = command
        self.operation = operation
        self.path = path
        self.url = url
        self.shortcutName = shortcutName
        self.confirm = confirm
        self.postRun = postRun
        self.children = children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName)
        shortcut = try container.decodeIfPresent(String.self, forKey: .shortcut)
        type = try container.decodeIfPresent(CustomActionType.self, forKey: .type) ?? .shell
        field = try container.decodeIfPresent(String.self, forKey: .field)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        operation = try container.decodeIfPresent(String.self, forKey: .operation)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        shortcutName = try container.decodeIfPresent(String.self, forKey: .shortcutName)
        confirm = try container.decodeIfPresent(CustomActionConfirmDefinition.self, forKey: .confirm)
        postRun = try container.decodeIfPresent(CustomActionPostRunDefinition.self, forKey: .postRun)
        children = try container.decodeIfPresent([CustomResultActionDefinition].self, forKey: .children) ?? []
    }
}

struct CustomAction: Hashable {
    let definition: CustomActionDefinition
    let directoryURL: URL

    var actionID: String {
        "custom.\(definition.id)"
    }

    var symbolName: String {
        definition.symbolName ?? "sparkle"
    }

    var isBuiltIn: Bool {
        definition.id.hasPrefix("built-in-")
    }
}

// MARK: - Result Model

struct CustomActionResult: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let text: String
    let tags: [String]
    let url: String?
    let path: String?
    let previewImagePath: String?
    let command: String?
    let presentation: CustomActionPresentation?
    let navigationCommand: String?
    let navigation: CustomResultNavigationDefinition?
    let accessories: [CustomResultAccessory]
    let metadata: [CustomResultMetadata]
    let isError: Bool
}

struct CustomResultAccessory: Codable, Hashable, Identifiable {
    var id: String { "\(symbolName ?? "")-\(text)-\(style ?? "")" }

    let text: String
    let symbolName: String?
    let style: String?
}

struct CustomResultMetadata: Codable, Hashable, Identifiable {
    var id: String { "\(label)-\(value)-\(url ?? "")" }

    let label: String
    let value: String
    let type: String?
    let url: String?
}

extension CustomActionResult {
    func value(for field: String?) -> String? {
        switch field {
        case "id":
            return id
        case "title":
            return title
        case "subtitle":
            return subtitle
        case "text", nil:
            return text
        case "url":
            return url
        case "path":
            return path
        case "previewImagePath":
            return previewImagePath
        case "command":
            return command
        default:
            return nil
        }
    }
}

extension CustomActionDefinition {
    static func manualShell(command: String) -> CustomActionDefinition {
        CustomActionDefinition(
            id: "result-shell",
            title: "Result Shell",
            subtitle: "",
            placeholder: nil,
            symbolName: nil,
            tags: [],
            type: .shell,
            command: command,
            path: nil,
            url: nil,
            shortcutName: nil,
            presentation: .direct,
            trigger: .manual
        )
    }
}
