import SwiftUI

extension CottageState {
    func moveCustomResultSelection(_ direction: MoveCommandDirection) {
        guard !customResults.isEmpty else {
            selectedCustomResultID = nil
            return
        }

        let currentIndex = customResults.firstIndex { $0.id == selectedCustomResultID } ?? 0
        switch direction {
        case .up:
            selectedCustomResultID = customResults[max(currentIndex - 1, 0)].id
        case .down:
            selectedCustomResultID = customResults[min(currentIndex + 1, customResults.count - 1)].id
        default:
            break
        }
    }

    func stopCustomProcess() {
        customProcess?.cancel()
        customProcess = nil
        customNativeTask?.cancel()
        customNativeTask = nil
        activeCustomProcessID = nil
    }
}
