// 给纯键盘模式虚拟焦点区域提供视觉边框
import SwiftUI

extension View {
    func keyboardFocusBorder(_ isFocused: Bool) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }
}
