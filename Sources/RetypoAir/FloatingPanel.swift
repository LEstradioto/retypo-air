import AppKit

final class FloatingPanel: NSPanel {
    init(settings: RetypoSettings) {
        let rect = settings.panelFrame.nsRect
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Retypo Air"
        isFloatingPanel = true
        level = settings.alwaysOnTop ? .floating : .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        minSize = NSSize(width: 520, height: 320)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
