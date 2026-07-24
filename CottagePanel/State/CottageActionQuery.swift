import Foundation

struct CottageActionQuery {
    enum Scope: Equatable {
        case all
        case actions
        case applications
        case tags
    }

    let scope: Scope
    let text: String

    init(_ rawQuery: String) {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(">") {
            scope = .actions
            text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if trimmed.hasPrefix("@") {
            scope = .applications
            text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if trimmed.hasPrefix("#") {
            scope = .tags
            text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            scope = .all
            text = trimmed
        }
    }
}

extension CottageAction {
    func matchesTagOnly(_ text: String) -> Bool {
        let normalizedText = normalizedSearchText(text)
        guard !normalizedText.isEmpty else {
            return !tags.isEmpty
        }

        return tags.contains { tag in
            normalizedSearchText(tag).contains(normalizedText)
        }
    }

    func matchesQuickName(_ text: String) -> Bool {
        let normalizedText = normalizedSearchText(text)
        guard !normalizedText.isEmpty else {
            return false
        }

        if normalizedSearchText(id).contains(normalizedText)
            || normalizedSearchText(title).contains(normalizedText) {
            return true
        }

        return tags.contains { tag in
            normalizedSearchText(tag).contains(normalizedText)
        }
    }
}
