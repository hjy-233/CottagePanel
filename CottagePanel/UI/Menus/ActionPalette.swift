// 显示动作可用操作的键盘化菜单
import SwiftUI

struct ActionPalette: View {
    let action: CottageAction
    @ObservedObject var state: CottageState

    var body: some View {
        CottageMenu(
            title: action.title,
            entries: menuEntries,
            onDismiss: {
                state.hideActionPalette()
            }
        )
    }

    private var menuEntries: [CottageMenuEntry] {
        var entries = customEntries
        if !entries.isEmpty {
            entries.append(.divider("custom-actions-divider"))
        }
        entries.append(contentsOf: secondaryEntries)
        return entries
    }

    private var customEntries: [CottageMenuEntry] {
        guard let customAction = action.customAction else {
            return []
        }

        return customAction.definition.actionMenuActions.map { menuAction in
            .item(
                menuItem(menuAction, customAction: customAction)
            )
        }
    }

    private func menuItem(
        _ menuAction: CustomMenuActionDefinition,
        customAction: CustomAction
    ) -> CottageMenuItem {
        CottageMenuItem(
            id: "custom-menu.\(menuAction.id)",
            title: menuAction.title,
            shortcut: CottageShortcut.displayText(for: menuAction.shortcut),
            symbolName: menuAction.symbolName ?? "sparkle",
            children: menuAction.children.map { child in
                menuItem(child, customAction: customAction)
            }
        ) {
            state.runCustomMenuAction(menuAction, for: customAction)
        }
    }

    private var secondaryEntries: [CottageMenuEntry] {
        state.secondaryActions(for: action).map { secondaryAction in
            .item(
                CottageMenuItem(
                    id: secondaryAction.id,
                    title: secondaryAction.title,
                    shortcut: secondaryAction.shortcut,
                    symbolName: secondaryAction.symbolName,
                    isDestructive: secondaryAction.isDestructive
                ) {
                    state.runSecondaryAction(secondaryAction)
                }
            )
        }
    }
}
