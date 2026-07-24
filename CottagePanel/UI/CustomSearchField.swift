import AppKit
import SwiftUI

struct CustomSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusTrigger: Int
    let onSubmit: () -> Void
    let onBackspaceWhenEmpty: () -> Bool
    let onMoveDownWhenEmpty: () -> Bool
    let onDropText: (String) -> Bool
    let onDropFiles: ([URL]) -> Bool

    init(
        text: Binding<String>,
        placeholder: String,
        focusTrigger: Int,
        onBackspaceWhenEmpty: @escaping () -> Bool = { false },
        onMoveDownWhenEmpty: @escaping () -> Bool = { false },
        onDropText: @escaping (String) -> Bool = { _ in false },
        onDropFiles: @escaping ([URL]) -> Bool = { _ in false },
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        self.placeholder = placeholder
        self.focusTrigger = focusTrigger
        self.onBackspaceWhenEmpty = onBackspaceWhenEmpty
        self.onMoveDownWhenEmpty = onMoveDownWhenEmpty
        self.onDropText = onDropText
        self.onDropFiles = onDropFiles
        self.onSubmit = onSubmit
    }

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
        textField.onDropText = context.coordinator.handleDroppedText
        textField.onDropFiles = context.coordinator.handleDroppedFiles
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
        context.coordinator.onBackspaceWhenEmpty = onBackspaceWhenEmpty
        context.coordinator.onMoveDownWhenEmpty = onMoveDownWhenEmpty
        context.coordinator.onDropText = onDropText
        context.coordinator.onDropFiles = onDropFiles
        if let searchTextField = textField as? SearchTextField {
            searchTextField.onDropText = context.coordinator.handleDroppedText
            searchTextField.onDropFiles = context.coordinator.handleDroppedFiles
        }

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
        var onBackspaceWhenEmpty: () -> Bool
        var onMoveDownWhenEmpty: () -> Bool
        var onDropText: (String) -> Bool
        var onDropFiles: ([URL]) -> Bool
        var placeholder: String
        var lastFocusTrigger = 0

        init(text: Binding<String>, onSubmit: @escaping () -> Void, placeholder: String) {
            self.text = text
            self.onSubmit = onSubmit
            self.onBackspaceWhenEmpty = { false }
            self.onMoveDownWhenEmpty = { false }
            self.onDropText = { _ in false }
            self.onDropFiles = { _ in false }
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
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                onSubmit()
                return true
            case #selector(NSResponder.deleteBackward(_:)):
                guard textView.string.isEmpty else {
                    return false
                }
                return onBackspaceWhenEmpty()
            case #selector(NSResponder.moveDown(_:)):
                guard textView.string.isEmpty else {
                    return false
                }
                return onMoveDownWhenEmpty()
            default:
                return false
            }
        }

        func handleDroppedText(_ text: String) -> Bool {
            onDropText(text)
        }

        func handleDroppedFiles(_ urls: [URL]) -> Bool {
            onDropFiles(urls)
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
    var onDropText: ((String) -> Bool)?
    var onDropFiles: (([URL]) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.string, .fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.string, .fileURL])
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 30)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        canReadDrop(from: sender.draggingPasteboard) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty {
            return onDropFiles?(urls) ?? false
        }

        if let text = pasteboard.string(forType: .string) {
            return onDropText?(text) ?? false
        }

        return false
    }

    private func canReadDrop(from pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self], options: nil)
            || pasteboard.string(forType: .string) != nil
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
