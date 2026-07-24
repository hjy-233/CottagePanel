import AppKit

struct CottageAction: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let kind: CottageActionKind
    let icon: NSImage?
    let fileURL: URL?
    let bundleIdentifier: String?
    let tags: [String]
    let customAction: CustomAction?
    let run: @MainActor () -> Void

    init(
        id: String,
        title: String,
        subtitle: String,
        symbolName: String,
        kind: CottageActionKind,
        icon: NSImage? = nil,
        fileURL: URL? = nil,
        bundleIdentifier: String? = nil,
        customAction: CustomAction? = nil,
        tags: [String],
        run: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.kind = kind
        self.icon = icon
        self.fileURL = fileURL
        self.bundleIdentifier = bundleIdentifier
        self.customAction = customAction
        self.tags = tags
        self.run = run
    }

    static func == (lhs: CottageAction, rhs: CottageAction) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func matches(_ text: String, initials: String) -> Bool {
        title.localizedCaseInsensitiveContains(text)
            || subtitle.localizedCaseInsensitiveContains(text)
            || tags.contains { $0.localizedCaseInsensitiveContains(text) }
            || (!initials.isEmpty && searchInitials(from: title).hasPrefix(initials))
            || (!initials.isEmpty && searchInitials(from: subtitle).hasPrefix(initials))
    }
}
