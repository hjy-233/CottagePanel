import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    func matches(_ event: NSEvent) -> Bool {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: self) else {
            return false
        }

        return Int(event.keyCode) == shortcut.carbonKeyCode
            && event.cottageShortcutModifiers == shortcut.modifiers.cottageShortcutModifiers
    }
}

private extension NSEvent {
    var cottageShortcutModifiers: NSEvent.ModifierFlags {
        modifierFlags.cottageShortcutModifiers
    }
}

private extension NSEvent.ModifierFlags {
    var cottageShortcutModifiers: NSEvent.ModifierFlags {
        intersection([.command, .shift, .option, .control])
    }
}
