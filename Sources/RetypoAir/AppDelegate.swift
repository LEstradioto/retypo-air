import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private var state: AppState?
    private var hotkeys: HotkeyService?

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

        appState.onAlwaysOnTopChanged = { [weak panel] enabled in
            panel?.level = enabled ? .floating : .normal
        }
        appState.onHideRequested = { [weak panel] in
            panel?.orderOut(nil)
        }
        appState.onShowRequested = { [weak self] in
            self?.showPanel()
        }

        hotkeys = HotkeyService { [weak self] in
            self?.togglePanel()
        }
        hotkeys?.register()

        showPanel()
        Task { await appState.refreshModelsIfPossible() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func showPanel() {
        guard let panel else { return }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) { persistFrame() }
    func windowDidResize(_ notification: Notification) { persistFrame() }
    func windowWillClose(_ notification: Notification) { persistFrame() }

    private func persistFrame() {
        guard let frame = panel?.frame, let state else { return }
        state.updatePanelFrame(frame)
    }
}
