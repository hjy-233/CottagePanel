import SwiftUI

@MainActor
enum CustomResultActionMenuItems {
    static func entries(
        resultActions: [CustomResultActionDefinition],
        result: CustomActionResult,
        state: CottageState
    ) -> [CottageMenuEntry] {
        resultActions.map { resultAction in
            .item(menuItem(resultAction, result: result, state: state))
        }
    }

    private static func menuItem(
        _ resultAction: CustomResultActionDefinition,
        result: CustomActionResult,
        state: CottageState
    ) -> CottageMenuItem {
        CottageMenuItem(
            id: "custom-result.\(resultAction.id)",
            title: resultAction.title,
            shortcut: CottageShortcut.displayText(for: resultAction.shortcut),
            symbolName: resultAction.symbolName ?? "sparkle",
            children: resultAction.children.map { child in
                menuItem(child, result: result, state: state)
            }
        ) {
            state.runCustomResultAction(resultAction, for: result)
        }
    }
}
