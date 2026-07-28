// 定义自定义 action 的扩展 API 字段
import Foundation

struct CustomSearchAccessoryDefinition: Codable, Hashable {
    let id: String
    let envKey: String?
    let defaultValue: String
    let items: [CustomPickerItemDefinition]

    private enum CodingKeys: String, CodingKey {
        case id
        case envKey
        case envName
        case defaultValue
        case items
    }

    var environmentName: String {
        "COTTAGE_ACCESSORY_\(normalizedEnvironmentKey(envKey ?? id))"
    }

    init(
        id: String,
        envKey: String?,
        defaultValue: String,
        items: [CustomPickerItemDefinition]
    ) {
        self.id = id
        self.envKey = envKey
        self.defaultValue = defaultValue
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyEnvName = try container.decodeIfPresent(String.self, forKey: .envName)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? legacyEnvName?.replacingOccurrences(of: "COTTAGE_", with: "").lowercased()
            ?? "filter"
        envKey = try container.decodeIfPresent(String.self, forKey: .envKey)
        defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue) ?? ""
        items = try container.decodeIfPresent([CustomPickerItemDefinition].self, forKey: .items) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(envKey, forKey: .envKey)
        try container.encode(defaultValue, forKey: .defaultValue)
        try container.encode(items, forKey: .items)
    }
}

struct CustomPickerItemDefinition: Codable, Hashable, Identifiable {
    let id: String
    let title: String
}

enum CustomFormFieldType: String, Codable {
    case text
    case password
    case textarea
    case checkbox
    case select
    case file
    case folder
}

struct CustomFormDefinition: Codable, Hashable {
    let fields: [CustomFormFieldDefinition]
}

struct CustomFormFieldDefinition: Codable, Hashable, Identifiable {
    let id: String
    let type: CustomFormFieldType
    let title: String
    let placeholder: String?
    let defaultValue: String?
    let required: Bool
    let acceptsDroppedContent: Bool
    let items: [CustomPickerItemDefinition]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(CustomFormFieldType.self, forKey: .type)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? id
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        defaultValue = try container.decodeIfPresent(String.self, forKey: .defaultValue)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        acceptsDroppedContent = try container.decodeIfPresent(Bool.self, forKey: .acceptsDroppedContent)
            ?? [.text, .textarea, .file, .folder].contains(type)
        items = try container.decodeIfPresent([CustomPickerItemDefinition].self, forKey: .items) ?? []
    }
}

struct CustomMenuBarDefinition: Codable, Hashable {
    let enabled: Bool
    let title: String?
    let symbolName: String?
    let order: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        title = try container.decodeIfPresent(String.self, forKey: .title)
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    }
}

struct CustomResultNavigationDefinition: Codable, Hashable {
    let command: String
    let title: String?
    let trigger: CustomActionTrigger?
    let searchPlaceholder: String?
}

func normalizedEnvironmentKey(_ key: String) -> String {
    key.uppercased().replacingOccurrences(of: "-", with: "_")
}

struct CustomActionPreviewDefinition: Codable, Hashable {
    let style: CustomActionPreviewStyle

    init(style: CustomActionPreviewStyle = .text) {
        self.style = style
    }
}

struct CustomActionInputDefinition: Codable, Hashable {
    let placeholder: String?
    let debounceMilliseconds: Int
    let allowsEmptyQuery: Bool
    let acceptsDroppedText: Bool
    let acceptsDroppedFiles: Bool
    let acceptedContentTypes: [String]

    init(
        placeholder: String? = nil,
        debounceMilliseconds: Int = 300,
        allowsEmptyQuery: Bool = true,
        acceptsDroppedText: Bool = true,
        acceptsDroppedFiles: Bool = true,
        acceptedContentTypes: [String] = ["public.text", "public.file-url"]
    ) {
        self.placeholder = placeholder
        self.debounceMilliseconds = debounceMilliseconds
        self.allowsEmptyQuery = allowsEmptyQuery
        self.acceptsDroppedText = acceptsDroppedText
        self.acceptsDroppedFiles = acceptsDroppedFiles
        self.acceptedContentTypes = acceptedContentTypes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        debounceMilliseconds = try container.decodeIfPresent(Int.self, forKey: .debounceMilliseconds) ?? 300
        allowsEmptyQuery = try container.decodeIfPresent(Bool.self, forKey: .allowsEmptyQuery) ?? true
        acceptsDroppedText = try container.decodeIfPresent(Bool.self, forKey: .acceptsDroppedText) ?? true
        acceptsDroppedFiles = try container.decodeIfPresent(Bool.self, forKey: .acceptsDroppedFiles) ?? true
        acceptedContentTypes = try container.decodeIfPresent([String].self, forKey: .acceptedContentTypes)
            ?? ["public.text", "public.file-url"]
    }
}

struct CustomActionConfirmDefinition: Codable, Hashable {
    let enabled: Bool
    let title: String?
    let message: String?
}

struct CustomActionPostRunDefinition: Codable, Hashable {
    let onSuccess: CustomActionPostRunBehavior?

    init(onSuccess: CustomActionPostRunBehavior? = nil) {
        self.onSuccess = onSuccess
    }
}
