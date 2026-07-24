import Foundation

struct CottageQueryChip: Equatable {
    enum Kind: Equatable {
        case action(String)
        case scope(CottageActionQuery.Scope)
    }

    let kind: Kind
    let title: String

    var scope: CottageActionQuery.Scope? {
        guard case let .scope(scope) = kind else {
            return nil
        }
        return scope
    }
}

extension CottageState {
    func normalizeQueryChipIfNeeded() -> Bool {
        guard !isApplyingQueryChip,
              activeCustomAction == nil,
              queryChipsEnabled,
              queryChip == nil else {
            return false
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let chip = queryChipMatch(from: trimmed) else {
            return false
        }

        isApplyingQueryChip = true
        queryChip = chip.chip
        query = chip.input
        if case let .action(actionID) = chip.chip.kind {
            selectedActionID = actionID
        } else {
            selectedActionID = filteredActions.first?.id
        }
        isApplyingQueryChip = false
        return true
    }

    func removeQueryChip() {
        queryChip = nil
        selectedActionID = filteredActions.first?.id
        focusSearch()
    }

    func handleSearchBackspaceWhenEmpty() -> Bool {
        if queryChip != nil {
            removeQueryChip()
            return true
        }

        guard activeCustomAction != nil else {
            return false
        }

        if popCustomNavigationStack() {
            return true
        }

        leaveCustomPanel()
        return true
    }

    func acceptDroppedText(_ text: String) -> Bool {
        guard droppedInputEnabled else {
            return false
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return false
        }

        if let activeCustomAction {
            guard activeCustomAction.definition.input.acceptsDroppedText else {
                return false
            }
            if activeCustomAction.definition.presentation == .form,
               applyDroppedTextToForm(trimmedText, in: activeCustomAction) {
                return true
            }
            customQuery = trimmedText
            return true
        }

        query = trimmedText
        return true
    }

    func acceptDroppedFiles(_ urls: [URL]) -> Bool {
        guard droppedInputEnabled, !urls.isEmpty else {
            return false
        }

        if let activeCustomAction {
            guard activeCustomAction.definition.input.acceptsDroppedFiles else {
                return false
            }
            if activeCustomAction.definition.presentation == .form,
               applyDroppedFilesToForm(urls, in: activeCustomAction) {
                return true
            }
            customQuery = urls.map(\.path).joined(separator: "\n")
            return true
        }

        query = urls.map(\.path).joined(separator: "\n")
        return true
    }
}

private extension CottageState {
    func queryChipMatch(from trimmed: String) -> (chip: CottageQueryChip, input: String)? {
        if trimmed.hasPrefix("/"),
           let match = quickCommandMatch(String(trimmed.dropFirst())) {
            return (
                CottageQueryChip(kind: .action(match.action.id), title: match.action.title),
                match.input
            )
        }

        if trimmed.hasPrefix(">") {
            return (
                CottageQueryChip(kind: .scope(.actions), title: L10n.text("queryChip.actions")),
                String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        if trimmed.hasPrefix("@") {
            return (
                CottageQueryChip(kind: .scope(.applications), title: L10n.text("queryChip.apps")),
                String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        if trimmed.hasPrefix("#") {
            return (
                CottageQueryChip(kind: .scope(.tags), title: L10n.text("queryChip.tags")),
                String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return nil
    }

    func applyDroppedTextToForm(_ text: String, in customAction: CustomAction) -> Bool {
        guard let field = customAction.definition.form?.fields.first(where: { field in
            field.acceptsDroppedContent && [.text, .textarea].contains(field.type)
        }) else {
            return false
        }

        updateFormValue(fieldID: field.id, value: text)
        return true
    }

    func applyDroppedFilesToForm(_ urls: [URL], in customAction: CustomAction) -> Bool {
        guard let field = customAction.definition.form?.fields.first(where: { field in
            field.acceptsDroppedContent && [.file, .folder].contains(field.type)
        }) else {
            return false
        }

        updateFormValue(fieldID: field.id, value: urls[0].path)
        return true
    }
}
