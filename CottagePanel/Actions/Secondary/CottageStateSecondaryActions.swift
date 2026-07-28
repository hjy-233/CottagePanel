// 生成和执行主动作列表中的二级操作菜单
import AppKit
import KeyboardShortcuts

extension CottageState {
    func runSecondaryAction(_ secondaryAction: CottageSecondaryAction) {
        guard let action = selectedAction else {
            return
        }

        secondaryAction.run(action)
        if secondaryAction.dismissesPalette {
            hideActionPalette()
        }
    }

    func runSecondaryAction(id: String) {
        guard let action = selectedAction,
              let secondaryAction = secondaryActions(for: action).first(where: { $0.id == id }) else {
            return
        }

        runSecondaryAction(secondaryAction)
    }

    func secondaryActions(for action: CottageAction) -> [CottageSecondaryAction] {
        var secondaryActions = baseSecondaryActions(for: action)

        if let fileURL = action.fileURL {
            secondaryActions.append(contentsOf: fileActions(for: fileURL))
        }

        if action.kind == .application, let fileURL = action.fileURL {
            secondaryActions.append(contentsOf: applicationActions(fileURL: fileURL))
        }

        return secondaryActions
    }

    private func baseSecondaryActions(for action: CottageAction) -> [CottageSecondaryAction] {
        [
            CottageSecondaryAction(
                id: "open",
                title: L10n.text("secondary.open"),
                shortcut: "⏎",
                symbolName: "arrow.up.forward.app"
            ) { [weak self] action in
                self?.run(action)
            },
            CottageSecondaryAction(
                id: "favorite",
                title: favoriteActionTitle(for: action),
                shortcut: shortcutLabel(.favoriteAction),
                symbolName: favoriteActionIDs.contains(action.id) ? "star.slash" : "star"
            ) { [weak self] action in
                self?.toggleFavorite(action)
            },
            CottageSecondaryAction(
                id: "copy-name",
                title: L10n.text("secondary.copyName"),
                shortcut: shortcutLabel(.copyName),
                symbolName: "doc.on.doc"
            ) { [weak self] action in
                self?.copyText(action.title)
            },
            CottageSecondaryAction(
                id: "delete-action",
                title: L10n.text("secondary.deleteAction"),
                shortcut: shortcutLabel(.deleteAction),
                symbolName: "minus.circle",
                isDestructive: true
            ) { [weak self] action in
                self?.deleteAction(action)
            }
        ]
    }

    private func favoriteActionTitle(for action: CottageAction) -> String {
        favoriteActionIDs.contains(action.id)
            ? L10n.text("secondary.removeFavorite")
            : L10n.text("secondary.addFavorite")
    }

    private func fileActions(for fileURL: URL) -> [CottageSecondaryAction] {
        [
            CottageSecondaryAction(
                id: "reveal",
                title: L10n.text("secondary.revealInFinder"),
                shortcut: shortcutLabel(.revealInFinder),
                symbolName: "folder"
            ) { [weak self] _ in
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                self?.showStatus(L10n.text("status.opened"))
            },
            CottageSecondaryAction(
                id: "copy-path",
                title: L10n.text("secondary.copyPath"),
                shortcut: shortcutLabel(.copyPath),
                symbolName: "point.topleft.down.curvedto.point.bottomright.up"
            ) { [weak self] _ in
                self?.copyText(fileURL.path)
            }
        ]
    }

    private func applicationActions(fileURL: URL) -> [CottageSecondaryAction] {
        [
            CottageSecondaryAction(
                id: "quit",
                title: L10n.text("secondary.quitApp"),
                shortcut: shortcutLabel(.quitApp),
                symbolName: "xmark.circle"
            ) { [weak self] action in
                terminateApplications(for: action, force: false)
                self?.showStatus(L10n.text("status.quitSent"))
            },
            CottageSecondaryAction(
                id: "force-quit",
                title: L10n.text("secondary.forceQuitApp"),
                shortcut: shortcutLabel(.forceQuitApp),
                symbolName: "xmark.octagon"
            ) { [weak self] action in
                self?.confirmDestructiveAction(
                    title: L10n.text("confirm.forceQuit.title"),
                    message: action.title
                ) {
                    terminateApplications(for: action, force: true)
                    self?.showStatus(L10n.text("status.forceQuitSent"))
                }
            },
            restartApplicationAction(fileURL: fileURL),
            CottageSecondaryAction(
                id: "uninstall",
                title: L10n.text("secondary.uninstallApp"),
                shortcut: shortcutLabel(.uninstallApp),
                symbolName: "trash",
                isDestructive: true
            ) { action in
                uninstallApplication(action, fileURL: fileURL)
            }
        ]
    }

    private func restartApplicationAction(fileURL: URL) -> CottageSecondaryAction {
        CottageSecondaryAction(
            id: "restart",
            title: L10n.text("secondary.restartApp"),
            shortcut: shortcutLabel(.restartApp),
            symbolName: "arrow.clockwise"
        ) { action in
            terminateApplications(for: action, force: false)
            self.showStatus(L10n.text("status.restartSent"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NSWorkspace.shared.open(fileURL)
            }
        }
    }

    private func shortcutLabel(_ name: KeyboardShortcuts.Name) -> String {
        KeyboardShortcuts.getShortcut(for: name).map {
            "\($0)"
                .replacingOccurrences(of: "Command", with: "⌘")
                .replacingOccurrences(of: "Shift", with: "⇧")
                .replacingOccurrences(of: "Option", with: "⌥")
                .replacingOccurrences(of: "Control", with: "⌃")
                .replacingOccurrences(of: "+", with: "")
        } ?? ""
    }
}
