import AppKit

final class FloatingPanel: NSPanel {
    init(settings: RetypoSettings) {
        let rect = settings.panelFrame.nsRect
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        title = "Retypo Air"
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = settings.alwaysOnTop ? .floating : .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        minSize = NSSize(width: 280, height: 78)
        for button in [standardWindowButton(.closeButton), standardWindowButton(.miniaturizeButton), standardWindowButton(.zoomButton)] {
            button?.isHidden = true
        }
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
