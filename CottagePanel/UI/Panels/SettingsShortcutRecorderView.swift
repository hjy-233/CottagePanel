// 桥接 KeyboardShortcuts 录入控件到 SwiftUI
import KeyboardShortcuts
import SwiftUI

struct SettingsShortcutRecorderView: NSViewRepresentable {
    let name: KeyboardShortcuts.Name
    let focusTrigger: Int
    let onChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(focusTrigger: focusTrigger)
    }

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        KeyboardShortcuts.RecorderCocoa(for: name) { _ in
            onChange()
        }
    }

    func updateNSView(_ nsView: KeyboardShortcuts.RecorderCocoa, context: Context) {
        nsView.shortcutName = name
        guard focusTrigger > 0,
              context.coordinator.focusTrigger != focusTrigger else {
            return
        }

        context.coordinator.focusTrigger = focusTrigger
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class Coordinator {
        var focusTrigger: Int

        init(focusTrigger: Int) {
            self.focusTrigger = focusTrigger
        }
    }
}
