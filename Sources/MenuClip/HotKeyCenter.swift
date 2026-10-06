import Carbon
import MenuClipCore

/// Registers system-wide shortcuts with Carbon's RegisterEventHotKey.
/// Unlike a global event monitor, this needs no special permission.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private static let signature: OSType = 0x4D43_6C70 // "MClp"

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    func register(_ hotKey: HotKey, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            NSLog("MenuClip: could not register \(hotKey.displayString) (error \(status)); another app may be using it")
            return
        }
        hotKeyRefs.append(ref)
        actions[id] = action
    }

    func unregisterAll() {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        actions.removeAll()
    }

    private func fire(_ id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
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
            guard status == noErr else { return status }
            let id = hotKeyID.id
            // Leave the Carbon callback before showing a menu.
            DispatchQueue.main.async { HotKeyCenter.shared.fire(id) }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
