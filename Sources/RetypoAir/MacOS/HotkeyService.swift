import AppKit
import Carbon

final class HotkeyService {
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
            service.handler()
            return noErr
        }, 1, &eventType, selfPointer, &eventHandler)

        let signature = OSType(UInt32(ascii: "RTYP"))
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(cmdKey | shiftKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}

private extension UInt32 {
    init(ascii string: String) {
        self = string.utf8.reduce(0) { ($0 << 8) + UInt32($1) }
    }
}
