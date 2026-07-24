import AppKit

extension AppDelegate {
    func shouldUseSystemTextEditing(for event: NSEvent) -> Bool {
        guard let textView = activeTextView(for: event),
              event.modifierFlags.contains(.command) else {
            return false
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        switch event.keyCode {
        case 0, 7, 9:
            return modifiers == [.command]
        case 8:
            return textView.selectedRange().length > 0
                && (modifiers == [.command] || modifiers == [.command, .shift])
        default:
            return false
        }
    }

    private func activeTextView(for event: NSEvent) -> NSTextView? {
        if let textView = event.window?.firstResponder as? NSTextView {
            return textView
        }

        return panel?.firstResponder as? NSTextView
    }
}
