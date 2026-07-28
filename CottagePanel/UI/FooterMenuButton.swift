// 渲染 Cottage 或 action 名称
import SwiftUI

struct FooterMenuButton: View {
    @ObservedObject var state: CottageState

    var body: some View {
        if let activeCustomAction = state.activeCustomAction {
            actionMenuButton(activeCustomAction)
        } else {
            appMenuButton
        }
    }

    private var appMenuButton: some View {
        menuButton(title: L10n.text("footer.appName")) {
            showMenu()
        }
        .popover(isPresented: $state.showsAppMenu, arrowEdge: .top) {
            CottageMenu(
                title: L10n.text("footer.appName"),
                entries: appMenuItems.map(CottageMenuEntry.item),
                onDismiss: {
                    state.showsAppMenu = false
                }
            )
        }
    }

    private func actionMenuButton(_ customAction: CustomAction) -> some View {
        menuButton(title: customAction.definition.title) {
            showMenu()
        }
        .popover(isPresented: $state.showsAppMenu, arrowEdge: .top) {
            CottageMenu(
                title: customAction.definition.title,
                entries: actionMenuEntries(for: customAction),
                onDismiss: {
                    state.showsAppMenu = false
                }
            )
        }
    }

    private func menuButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 180, alignment: .leading)
    }

    private func showMenu() {
        state.keyboardContext = .actionMenu
        state.showsAppMenu = true
    }

    private var appMenuItems: [CottageMenuItem] {
        [
            CottageMenuItem(
                id: "open-settings",
                title: L10n.text("appMenu.openSettings"),
                shortcut: "⌘,",
                symbolName: "gearshape"
            ) {
                state.openSettingsFromMenu()
            },
            CottageMenuItem(
                id: "quit-cottage",
                title: L10n.text("appMenu.quitCottage"),
                shortcut: "⌘Q",
                symbolName: "power",
                isDestructive: true
            ) {
                state.quitFromMenu()
            }
        ]
    }

    private func actionMenuEntries(for customAction: CustomAction) -> [CottageMenuEntry] {
        var entries = customAction.definition.actionMenuActions.map { menuAction in
            CottageMenuEntry.item(actionMenuItem(menuAction, customAction: customAction))
        }
        if let selectedCustomResult = state.selectedCustomResult,
           !customAction.definition.resultActions.isEmpty {
            if !entries.isEmpty {
                entries.append(.divider("selected-result-actions-divider"))
            }
            entries.append(
                contentsOf: CustomResultActionMenuItems.entries(
                    resultActions: customAction.definition.resultActions,
                    result: selectedCustomResult,
                    state: state
                )
            )
        }

        guard !entries.isEmpty else {
            return [
                .item(
                    CottageMenuItem(
                        id: "custom-action.empty",
                        title: L10n.text("actionMenu.empty"),
                        shortcut: nil,
                        symbolName: "info.circle"
                    ) {}
                )
            ]
        }

        return entries
    }

    private func actionMenuItem(
        _ menuAction: CustomMenuActionDefinition,
        customAction: CustomAction
    ) -> CottageMenuItem {
        CottageMenuItem(
            id: "custom-menu.\(menuAction.id)",
            title: menuAction.title,
            shortcut: CottageShortcut.displayText(for: menuAction.shortcut),
            symbolName: menuAction.symbolName ?? "sparkle",
            children: menuAction.children.map { child in
                actionMenuItem(child, customAction: customAction)
            }
        ) {
            state.runCustomMenuAction(menuAction, for: customAction)
        }
    }
}
