import AppKit
import SwiftUI

struct CustomSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusTrigger: Int
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = SearchTextField()
        textField.backgroundColor = .clear
        textField.bezelStyle = .roundedBezel
        textField.cell = VerticallyCenteredTextFieldCell()
        textField.delegate = context.coordinator
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 20)
        textField.isBordered = false
        textField.isEditable = true
        textField.isSelectable = true
        textField.lineBreakMode = .byTruncatingTail
        textField.placeholderAttributedString = placeholderString
        textField.stringValue = text
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        if textField.stringValue != text {
            textField.stringValue = text
        }
        if context.coordinator.placeholder != placeholder {
            context.coordinator.placeholder = placeholder
            textField.placeholderAttributedString = placeholderString
        }
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit

        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                textField.window?.makeFirstResponder(textField)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, placeholder: placeholder)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void
        var placeholder: String
        var lastFocusTrigger = 0

        init(text: Binding<String>, onSubmit: @escaping () -> Void, placeholder: String) {
            self.text = text
            self.onSubmit = onSubmit
            self.placeholder = placeholder
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }

            text.wrappedValue = textField.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }

            onSubmit()
            return true
        }
    }

    private var placeholderString: NSAttributedString {
        NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 20)
            ]
        )
    }
}

final class SearchTextField: NSTextField {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 30)
    }
}

final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let originalRect = super.drawingRect(forBounds: rect)
        let heightDelta = rect.height - originalRect.height
        return originalRect.offsetBy(dx: 0, dy: heightDelta / 2)
    }

    override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        super.edit(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            event: event
        )
    }

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        super.select(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: selStart,
            length: selLength
        )
    }
}
