import AppKit

final class KeyableAuxiliaryPanel: NSPanel {
    var onTabKey: (() -> Void)?
    var onShiftTabKey: (() -> Void)?
    var onEnterKey: (() -> Bool)?
    var onCloseKey: (() -> Void)?
    var onCommandSKey: (() -> Void)?
    var onToggleCandidatesKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handlePanelShortcut(event) {
            return
        }
        super.sendEvent(event)
    }

    override func keyDown(with event: NSEvent) {
        if handlePanelShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handlePanelShortcut(_ event: NSEvent) -> Bool {
        if event.keyCode == 48 { // tab
            if event.modifierFlags.contains(.shift) {
                guard let onShiftTabKey else { return false }
                onShiftTabKey()
            } else {
                guard let onTabKey else { return false }
                onTabKey()
            }
            return true
        }
        if event.keyCode == 13, event.modifierFlags.contains(.control) { // Ctrl+W
            guard let onCloseKey else { return false }
            onCloseKey()
            return true
        }
        if event.keyCode == 1, event.modifierFlags.contains(.command) { // Cmd+S
            guard let onCommandSKey else { return false }
            onCommandSKey()
            return true
        }
        if event.keyCode == 2, event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) { // Cmd/Ctrl+D
            guard let onToggleCandidatesKey else { return false }
            onToggleCandidatesKey()
            return true
        }
        if event.keyCode == 36 || event.keyCode == 76 { // enter
            guard let onEnterKey else { return false }
            return onEnterKey()
        }
        return false
    }
}
