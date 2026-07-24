import Foundation

extension CottageState {
    var commandShortcutActions: [CottageAction] {
        guard activeCustomAction == nil else {
            return []
        }

        let snapshotActions = filteredActions.filter { commandShortcutActionIDs.contains($0.id) }
        guard !snapshotActions.isEmpty else {
            return Array(filteredActions.prefix(10))
        }

        return Array(snapshotActions.prefix(10))
    }

    var commandShortcutCustomResults: [CustomActionResult] {
        guard activeCustomAction != nil else {
            return []
        }

        let snapshotResults = customResults.filter { commandShortcutCustomResultIDs.contains($0.id) }
        guard !snapshotResults.isEmpty else {
            return Array(customResults.prefix(10))
        }

        return Array(snapshotResults.prefix(10))
    }

    func markActionVisible(_ action: CottageAction) {
        visibleActionIDs.insert(action.id)
    }

    func markActionHidden(_ action: CottageAction) {
        visibleActionIDs.remove(action.id)
    }

    func markCustomResultVisible(_ result: CustomActionResult) {
        visibleCustomResultIDs.insert(result.id)
    }

    func markCustomResultHidden(_ result: CustomActionResult) {
        visibleCustomResultIDs.remove(result.id)
    }

    func prepareCommandShortcutSnapshot() {
        if activeCustomAction == nil {
            let visibleActions = filteredActions.filter { visibleActionIDs.contains($0.id) }
            commandShortcutActionIDs = visibleActions.prefix(10).map { $0.id }
            commandShortcutCustomResultIDs = []
        } else {
            let visibleResults = customResults.filter { visibleCustomResultIDs.contains($0.id) }
            commandShortcutActionIDs = []
            commandShortcutCustomResultIDs = visibleResults.prefix(10).map { $0.id }
        }
    }

    func clearCommandShortcutSnapshot() {
        commandShortcutActionIDs = []
        commandShortcutCustomResultIDs = []
    }

    func setCommandActionHintsVisible(_ isVisible: Bool) {
        guard showsCommandActionHints != isVisible else {
            return
        }

        showsCommandActionHints = isVisible
        if !isVisible {
            clearCommandShortcutSnapshot()
        }
    }

    func commandShortcutLabel(for action: CottageAction) -> String? {
        guard showsCommandActionHints,
              let index = commandShortcutActions.firstIndex(where: { $0.id == action.id }) else {
            return nil
        }

        return shortcutLabel(for: index)
    }

    func commandShortcutLabel(for result: CustomActionResult) -> String? {
        guard showsCommandActionHints,
              let index = commandShortcutCustomResults.firstIndex(where: { $0.id == result.id }) else {
            return nil
        }

        return shortcutLabel(for: index)
    }

    func runCommandShortcut(index: Int) {
        if activeCustomAction != nil {
            guard let result = commandShortcutCustomResults[safe: index] else {
                return
            }
            selectedCustomResultID = result.id
            executeCustomResult(result)
            return
        }

        guard let action = commandShortcutActions[safe: index] else {
            return
        }

        run(action)
    }

    private func shortcutLabel(for index: Int) -> String {
        "⌘\(index == 9 ? "0" : "\(index + 1)")"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }
}
