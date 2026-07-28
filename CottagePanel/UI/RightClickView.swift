// 把 AppKit 右键事件转发给 SwiftUI 状态层
import AppKit
import SwiftUI

struct RightClickView: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> RightClickNSView {
        RightClickNSView(action: action)
    }

    func updateNSView(_ view: RightClickNSView, context: Context) {
        view.action = action
    }
}

final class RightClickNSView: NSView {
    var action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard NSApp.currentEvent?.type == .rightMouseDown else {
            return nil
        }

        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        action()
    }
}
