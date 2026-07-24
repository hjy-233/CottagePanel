import Foundation

extension CottageState {
    func scheduleRecentSearchCapture() {
        recentSearchWorkItem?.cancel()
        guard let entry = currentRecentSearchEntry() else {
            return
        }

        let workItem = DispatchWorkItem {
            RecentSearchStore.record(entry)
        }
        recentSearchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(700), execute: workItem)
    }

    func recordRecentSearchNow() {
        recentSearchWorkItem?.cancel()
        guard let entry = currentRecentSearchEntry() else {
            return
        }

        RecentSearchStore.record(entry)
    }

    func recordRecentSearch(input: String, for action: CottageAction) {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let customAction = action.customAction,
              customAction.definition.presentation != .form,
              !value.isEmpty,
              !looksSensitiveRecentSearch(value) else {
            return
        }

        let accessoryValue = defaultAccessoryValue(for: customAction)
        RecentSearchStore.record(
            RecentSearchEntry(
                id: UUID().uuidString,
                scope: .custom,
                actionID: customAction.definition.id,
                actionTitle: customAction.definition.title,
                query: value,
                accessoryValue: accessoryValue,
                savedAt: Date()
            )
        )
    }

    func restoreRecentSearchResultIfNeeded(_ result: CustomActionResult) -> Bool {
        guard let command = result.command,
              command.hasPrefix(RecentSearchCommand.prefix) else {
            return false
        }

        let id = String(command.dropFirst(RecentSearchCommand.prefix.count))
        guard let entry = RecentSearchStore.entry(id: id) else {
            showStatus(L10n.text("recentSearch.missing"))
            return true
        }

        restoreRecentSearch(entry)
        return true
    }

    private func currentRecentSearchEntry() -> RecentSearchEntry? {
        guard !isRestoringRecentSearch else {
            return nil
        }

        if let activeCustomAction {
            return currentCustomRecentSearchEntry(activeCustomAction)
        }

        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard queryChip == nil,
              !value.isEmpty,
              !looksSensitiveRecentSearch(value) else {
            return nil
        }

        return RecentSearchEntry(
            id: UUID().uuidString,
            scope: .main,
            actionID: nil,
            actionTitle: nil,
            query: value,
            accessoryValue: "",
            savedAt: Date()
        )
    }

    private func currentCustomRecentSearchEntry(_ customAction: CustomAction) -> RecentSearchEntry? {
        let definition = customAction.definition
        let value = customQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard definition.id != NativeBuiltInPanelActionID.recentSearch.rawValue,
              definition.presentation != .form,
              !value.isEmpty,
              !looksSensitiveRecentSearch(value) else {
            return nil
        }

        return RecentSearchEntry(
            id: UUID().uuidString,
            scope: .custom,
            actionID: definition.id,
            actionTitle: definition.title,
            query: value,
            accessoryValue: customAccessoryValue,
            savedAt: Date()
        )
    }

    private func restoreRecentSearch(_ entry: RecentSearchEntry) {
        isRestoringRecentSearch = true
        defer {
            isRestoringRecentSearch = false
            focusSearch()
        }

        switch entry.scope {
        case .main:
            restoreMainRecentSearch(entry)
        case .custom:
            restoreCustomRecentSearch(entry)
        }
        showStatus(L10n.text("recentSearch.restored"))
    }

    private func restoreMainRecentSearch(_ entry: RecentSearchEntry) {
        if activeCustomAction != nil {
            leaveCustomPanel()
        }
        queryChip = nil
        query = entry.query
        selectedActionID = filteredActions.first?.id
    }

    private func restoreCustomRecentSearch(_ entry: RecentSearchEntry) {
        guard let actionID = entry.actionID,
              let action = actions.first(where: { $0.customAction?.definition.id == actionID }),
              let customAction = action.customAction else {
            showStatus(L10n.text("recentSearch.missing"))
            return
        }

        runCustomAction(customAction)
        guard activeCustomAction?.definition.id == customAction.definition.id else {
            return
        }
        if let accessory = customAction.definition.searchAccessory,
           accessory.items.contains(where: { $0.id == entry.accessoryValue }) {
            customAccessoryValue = entry.accessoryValue
        }
        customQuery = entry.query
        if customAction.definition.trigger == .manual {
            customResults = []
            selectedCustomResultID = nil
        }
    }
}

private func looksSensitiveRecentSearch(_ value: String) -> Bool {
    let lowercasedValue = value.lowercased()
    let sensitiveMarkers = [
        "password",
        "passwd",
        "secret",
        "token",
        "api_key",
        "apikey",
        "private_key",
        "bearer ",
        "sk-"
    ]
    return sensitiveMarkers.contains { lowercasedValue.contains($0) }
}
