// 定义内部快捷键模型和系统事件匹配逻辑
import AppKit

struct CottageShortcut: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let key: String

    init?(event: NSEvent) {
        guard let shortcutKey = Self.key(for: event),
              let keyCode = Self.keyCodes[shortcutKey] else {
            return nil
        }

        self.keyCode = keyCode
        modifiers = Self.normalized(event.modifierFlags)
        key = shortcutKey
    }

    init?(_ text: String?) {
        guard let text else {
            return nil
        }

        let lowercased = text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        var modifiers = NSEvent.ModifierFlags()
        if lowercased.contains("cmd") || lowercased.contains("⌘") {
            modifiers.insert(.command)
        }
        if lowercased.contains("shift") || lowercased.contains("⇧") {
            modifiers.insert(.shift)
        }
        if lowercased.contains("option") || lowercased.contains("opt") || lowercased.contains("⌥") {
            modifiers.insert(.option)
        }
        if lowercased.contains("ctrl") || lowercased.contains("control") || lowercased.contains("⌃") {
            modifiers.insert(.control)
        }

        guard let key = Self.key(for: lowercased),
              let keyCode = Self.keyCodes[key] else {
            return nil
        }

        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    var displayText: String {
        var text = ""
        if modifiers.contains(.control) {
            text.append("⌃")
        }
        if modifiers.contains(.option) {
            text.append("⌥")
        }
        if modifiers.contains(.shift) {
            text.append("⇧")
        }
        if modifiers.contains(.command) {
            text.append("⌘")
        }
        text.append(displayKey)
        return text
    }

    static func displayText(for shortcut: String?) -> String? {
        CottageShortcut(shortcut)?.displayText
    }

    private static func normalized(_ modifiers: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        modifiers.intersection([.command, .shift, .option, .control])
    }

    private static func keyCode(for event: NSEvent) -> UInt16? {
        event.charactersIgnoringModifiers
            .flatMap { keyCode(for: $0.lowercased()) }
    }

    private static func key(for event: NSEvent) -> String? {
        if event.keyCode == 51 {
            return "delete"
        }

        if let key = keyCodes.first(where: { $0.value == event.keyCode })?.key {
            return key
        }

        return event.charactersIgnoringModifiers
            .flatMap { key(for: $0.lowercased()) }
    }

    private static func keyCode(for text: String) -> UInt16? {
        key(for: text).flatMap { keyCodes[$0] }
    }

    private static func key(for text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "cmd", with: "")
            .replacingOccurrences(of: "command", with: "")
            .replacingOccurrences(of: "shift", with: "")
            .replacingOccurrences(of: "option", with: "")
            .replacingOccurrences(of: "opt", with: "")
            .replacingOccurrences(of: "control", with: "")
            .replacingOccurrences(of: "ctrl", with: "")
            .replacingOccurrences(of: "⌘", with: "")
            .replacingOccurrences(of: "⇧", with: "")
            .replacingOccurrences(of: "⌥", with: "")
            .replacingOccurrences(of: "⌃", with: "")
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "-", with: "")

        guard keyCodes[cleaned] != nil else {
            return nil
        }

        return cleaned
    }

    private var displayKey: String {
        switch key {
        case "delete", "backspace":
            "⌫"
        default:
            key.uppercased()
        }
    }

    private static let keyCodes: [String: UInt16] = [
        "a": 0,
        "s": 1,
        "d": 2,
        "f": 3,
        "h": 4,
        "g": 5,
        "z": 6,
        "x": 7,
        "c": 8,
        "v": 9,
        "b": 11,
        "q": 12,
        "w": 13,
        "e": 14,
        "r": 15,
        "y": 16,
        "t": 17,
        "1": 18,
        "2": 19,
        "3": 20,
        "4": 21,
        "6": 22,
        "5": 23,
        "=": 24,
        "9": 25,
        "7": 26,
        "-": 27,
        "8": 28,
        "0": 29,
        "o": 31,
        "u": 32,
        "i": 34,
        "p": 35,
        "l": 37,
        "j": 38,
        "k": 40,
        "n": 45,
        "m": 46,
        "delete": 51,
        "backspace": 51,
        "⌫": 51
    ]
}
