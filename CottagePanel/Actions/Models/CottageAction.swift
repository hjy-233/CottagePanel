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

    func matches(_ text: String, initials: String, allowsFuzzy: Bool = false) -> Bool {
        let exactMatch = title.localizedCaseInsensitiveContains(text)
            || subtitle.localizedCaseInsensitiveContains(text)
            || tags.contains { $0.localizedCaseInsensitiveContains(text) }
            || (!initials.isEmpty && searchInitials(from: title).hasPrefix(initials))
            || (!initials.isEmpty && searchInitials(from: subtitle).hasPrefix(initials))
        guard !exactMatch, allowsFuzzy else {
            return exactMatch
        }

        return fuzzySearchMatches(text, in: [title, subtitle] + tags)
    }
}

func fuzzySearchMatches(_ query: String, in candidates: [String]) -> Bool {
    let normalizedQuery = normalizedSearchText(query)
    guard !normalizedQuery.isEmpty else {
        return true
    }

    return candidates.contains { candidate in
        normalizedTextContainsFuzzyQuery(normalizedSearchText(candidate), query: normalizedQuery)
    }
}

private func normalizedTextContainsFuzzyQuery(_ text: String, query: String) -> Bool {
    guard query.count <= text.count else {
        return false
    }

    var index = text.startIndex
    for character in query {
        guard let matchIndex = text[index...].firstIndex(of: character) else {
            return false
        }
        index = text.index(after: matchIndex)
    }
    return true
}
