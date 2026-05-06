import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private var state: AppState?
    private var hotkeys: HotkeyService?
    private var auxiliaryPanels: AuxiliaryPanelController?
    private var previousApplication: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsStore.load()
        let appState = AppState(settings: settings)
        self.state = appState

        let rootView = RetypoView()
            .environmentObject(appState)

        let panel = FloatingPanel(settings: settings)
        panel.contentView = NSHostingView(rootView: rootView)
        panel.delegate = self
        self.panel = panel
        let auxiliaryPanels = AuxiliaryPanelController(mainPanel: panel, state: appState)
        self.auxiliaryPanels = auxiliaryPanels

        appState.onAlwaysOnTopChanged = { [weak panel] enabled in
            panel?.level = enabled ? .floating : .normal
        }
        appState.onHideRequested = { [weak self] in
            self?.hidePanelAndFocusPrevious()
        }
        appState.onShowRequested = { [weak self] in
            self?.showPanel()
        }
        appState.onSettingsRequested = { [weak self] in
            self?.auxiliaryPanels?.toggleSettings()
        }
        appState.onCandidatesVisibilityChanged = { [weak self] visible in
            self?.auxiliaryPanels?.setCandidatesVisible(visible)
        }

        hotkeys = HotkeyService { [weak self] in
            self?.togglePanel()
        }
        hotkeys?.register()

        showPanel()
        Task { await appState.refreshModelsIfPossible() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidBecomeActive(_ notification: Notification) {
        focusEditorIfPossible()
    }

    private func showPanel() {
        rememberPreviousApplication()
        guard let panel else { return }
        positionPanelForActiveScreenIfNeeded()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.focusEditorIfPossible()
        }
    }

    private func hidePanelAndFocusPrevious() {
        panel?.orderOut(nil)
        if let previousApplication, !previousApplication.isTerminated {
            previousApplication.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible, NSApp.isActive, panel.isKeyWindow {
            hidePanelAndFocusPrevious()
        } else {
            showPanel()
        }
    }

    private func rememberPreviousApplication() {
        let current = NSWorkspace.shared.frontmostApplication
        if current?.processIdentifier != NSRunningApplication.current.processIdentifier {
            previousApplication = current
        }
    }

    private func positionPanelForActiveScreenIfNeeded() {
        guard state?.settings.followActiveScreenOnShow == true, let panel else { return }
        let screen = screenForCurrentMouse() ?? panel.screen ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let width = max(280, visible.width / 3)
        let height = min(max(panel.frame.height, panel.minSize.height), visible.height * 0.55)
        let x = visible.minX + (visible.width - width) / 2
        let y = visible.minY + 34
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }

    private func screenForCurrentMouse() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private func focusEditorIfPossible() {
        guard state?.showSettings != true, panel?.isVisible == true else { return }
        guard let editor = panel?.contentView?.firstSubview(of: KeyHandlingTextView.self) else { return }
        panel?.makeFirstResponder(editor)
    }
}

private extension NSView {
    func firstSubview<T: NSView>(of type: T.Type) -> T? {
        if let view = self as? T { return view }
        for subview in subviews {
            if let found = subview.firstSubview(of: type) { return found }
        }
        return nil
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) { focusEditorIfPossible() }
    func windowDidMove(_ notification: Notification) { persistFrame(); auxiliaryPanels?.repositionCandidatesIfVisible() }
    func windowDidResize(_ notification: Notification) { persistFrame(); auxiliaryPanels?.repositionCandidatesIfVisible() }
    func windowWillClose(_ notification: Notification) { persistFrame() }

    private func persistFrame() {
        guard let frame = panel?.frame, let state else { return }
        state.updatePanelFrame(frame)
    }
}
