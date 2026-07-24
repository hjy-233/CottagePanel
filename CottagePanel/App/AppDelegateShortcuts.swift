import AppKit
import KeyboardShortcuts

extension AppDelegate {
    func commandShortcutIndex(for event: NSEvent) -> Int? {
        [
            18: 0,
            19: 1,
            20: 2,
            21: 3,
            23: 4,
            22: 5,
            26: 6,
            28: 7,
            25: 8,
            29: 9
        ][event.keyCode]
    }

    func secondaryActionID(for event: NSEvent) -> String? {
        if event.keyCode == 36 {
            return "open"
        }

        for shortcut in secondaryShortcuts {
            guard shortcut.name.matches(event) else {
                continue
            }

            return shortcut.id
        }

        return nil
    }

    private var secondaryShortcuts: [(id: String, name: KeyboardShortcuts.Name)] {
        [
            ("favorite", .favoriteAction),
            ("reveal", .revealInFinder),
            ("copy-name", .copyName),
            ("copy-path", .copyPath),
            ("quit", .quitApp),
            ("force-quit", .forceQuitApp),
            ("restart", .restartApp),
            ("delete-action", .deleteAction),
            ("uninstall", .uninstallApp)
        ]
    }
}
