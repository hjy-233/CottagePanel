import AppKit
import Foundation

extension CottageState {
    var isActionMenuPresented: Bool {
        showsActionPalette || shownCustomResultMenuID != nil || showsAppMenu
    }

    func cycleKeyboardContext(reverse: Bool) {
        let contexts: [CottageKeyboardContext] = [.search, .list, .preview, .footer]
        let currentIndex = contexts.firstIndex(of: keyboardContext) ?? 0
        let offset = reverse ? -1 : 1
        let nextIndex = (currentIndex + offset + contexts.count) % contexts.count
        keyboardContext = contexts[nextIndex]
        focusSearch()
    }

    func moveKeyboardContext(_ direction: CottageKeyboardDirection) {
        switch direction {
        case .moveUp:
            keyboardContext = .search
        case .moveDown:
            keyboardContext = keyboardContext == .search ? .list : .footer
        case .moveLeft:
            keyboardContext = keyboardContext == .preview ? .list : .search
        case .moveRight:
            keyboardContext = keyboardContext == .list ? .preview : .list
        }
        focusSearch()
    }

    func enterQuestionNumberPrefix() {
        questionNumberWorkItem?.cancel()
        prepareCommandShortcutSnapshot()
        showsQuestionNumberPrefix = true
        showStatus(L10n.text("status.menuPrefix"))
        let workItem = DispatchWorkItem { [weak self] in
            self?.showsQuestionNumberPrefix = false
            self?.questionNumberWorkItem = nil
        }
        questionNumberWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    func cancelQuestionNumberPrefix() {
        questionNumberWorkItem?.cancel()
        questionNumberWorkItem = nil
        showsQuestionNumberPrefix = false
    }

    func showMenuForCommandShortcut(index: Int) {
        cancelQuestionNumberPrefix()
        if activeCustomAction != nil {
            let results = commandShortcutCustomResults
            guard results.indices.contains(index) else {
                return
            }
            let result = results[index]
            showCustomResultMenu(for: result)
            return
        }

        let actions = commandShortcutActions
        guard actions.indices.contains(index) else {
            return
        }

        let action = actions[index]
        selectedActionID = action.id
        showsActionPalette = true
        keyboardContext = .actionMenu
    }

    func runQuickQueryIfNeeded() -> Bool {
        guard activeCustomAction == nil else {
            return false
        }

        if let queryChip,
           case let .action(actionID) = queryChip.kind,
           let action = actions.first(where: { $0.id == actionID }) {
            let input = query
            recordRecentSearch(input: input, for: action)
            self.queryChip = nil
            query = ""
            run(action)
            applyQuickInput(input, to: action)
            return true
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedSearchText(trimmed)
        if normalized == "settings" {
            query = ""
            openSettings()
            return true
        }
        if normalized == "reload" {
            query = ""
            reloadActionsFromUserAction()
            return true
        }
        if trimmed.hasPrefix("/") {
            return runSlashCommand(trimmed)
        }
        return false
    }

    private func runSlashCommand(_ commandText: String) -> Bool {
        let command = String(commandText.dropFirst())
        guard let match = quickCommandMatch(command) else {
            return false
        }

        recordRecentSearch(input: match.input, for: match.action)
        query = ""
        run(match.action)
        applyQuickInput(match.input, to: match.action)
        return true
    }

    func quickCommandMatch(_ command: String) -> (action: CottageAction, input: String)? {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = actions.compactMap { action -> (action: CottageAction, aliases: [String])? in
            guard let customAction = action.customAction else {
                return nil
            }
            switch customAction.definition.presentation {
            case .panel, .popup, .form:
                return (action, quickAliases(for: action))
            case .direct:
                return nil
            }
        }

        for candidate in candidates.sorted(by: { lhs, rhs in
            (lhs.aliases.map(\.count).max() ?? 0) > (rhs.aliases.map(\.count).max() ?? 0)
        }) {
            if let input = quickInput(trimmedCommand, matching: candidate.aliases) {
                return (candidate.action, input)
            }
        }

        return nil
    }

    private func quickAliases(for action: CottageAction) -> [String] {
        var aliases = [action.id, action.title]
        aliases.append(contentsOf: action.tags)
        if action.id == "built-in.fileSearch" {
            aliases.append(contentsOf: ["file", "files", "search files", "搜索文件"])
        }
        return aliases
    }

    private func quickInput(_ command: String, matching aliases: [String]) -> String? {
        for alias in aliases.sorted(by: { $0.count > $1.count }) {
            let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAlias.isEmpty else {
                continue
            }

            if command.localizedCaseInsensitiveCompare(trimmedAlias) == .orderedSame {
                return ""
            }

            let prefix = "\(trimmedAlias) "
            if command.localizedCaseInsensitiveCompare(prefix) == .orderedSame {
                return ""
            }

            if command.lowercased().hasPrefix(prefix.lowercased()) {
                return String(command.dropFirst(prefix.count))
            }
        }

        let compactCommand = normalizedSearchText(command)
        for alias in aliases.sorted(by: { $0.count > $1.count }) {
            let compactAlias = normalizedSearchText(alias)
            guard !compactAlias.isEmpty, compactCommand.hasPrefix(compactAlias) else {
                continue
            }
            let inputStart = command.index(command.startIndex, offsetBy: min(alias.count, command.count))
            return String(command[inputStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func applyQuickInput(_ input: String, to action: CottageAction) {
        guard let customAction = action.customAction else {
            customQuery = input
            return
        }

        switch customAction.definition.presentation {
        case .panel:
            customQuery = input
        case .popup:
            popupInput = input
        case .form:
            customQuery = input
            fillFirstTextLikeFormField(input, for: customAction)
        case .direct:
            break
        }
    }

    private func fillFirstTextLikeFormField(_ value: String, for customAction: CustomAction) {
        guard let field = customAction.definition.form?.fields.first(where: { field in
            [.text, .password, .textarea].contains(field.type)
        }) else {
            return
        }

        updateFormValue(fieldID: field.id, value: value)
    }
}
