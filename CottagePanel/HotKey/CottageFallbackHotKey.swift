// 在快捷键库不可用时提供本地全局快捷键
import Carbon.HIToolbox
import Foundation

@MainActor
final class CottageFallbackHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: @MainActor () -> Void

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
        installHandler()
        registerHotKey()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            userData,
            &handlerRef
        )
        if status != noErr {
            NSLog("CottagePanel cannot install fallback hotkey handler: \(status)")
        }
    }

    private func registerHotKey() {
        let hotKeyID = EventHotKeyID(
            signature: fourCharacterCode("Cotg"),
            id: 1
        )
        let modifiers = UInt32(cmdKey | shiftKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("CottagePanel cannot register fallback hotkey: \(status)")
        }
    }

    fileprivate func runAction() {
        action()
    }
}

private let hotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.id == 1 else {
        return noErr
    }

    Task { @MainActor in
        let hotKey = Unmanaged<CottageFallbackHotKey>
            .fromOpaque(userData)
            .takeUnretainedValue()
        hotKey.runAction()
    }
    return noErr
}

private func fourCharacterCode(_ text: String) -> OSType {
    text.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
