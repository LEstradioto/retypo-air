import AppKit
import SwiftUI

@MainActor
final class AuxiliaryPanelController {
    private weak var mainPanel: NSWindow?
    private weak var state: AppState?
    private let settingsFocus = SettingsFocusCoordinator()
    private var settingsPanel: NSPanel?
    private var candidatesPanel: NSPanel?
    private var importPromptPanel: NSPanel?

    init(mainPanel: NSWindow, state: AppState) {
        self.mainPanel = mainPanel
        self.state = state
    }

    func showSettings() {
        guard let state else { return }
        state.showSettings = true
        if settingsPanel == nil {
            let panel = makePanel(width: 780, height: 720, minWidth: 560, minHeight: 420, radius: 24)
            panel.contentView = roundedHostingView(rootView: SettingsView().environmentObject(state).environmentObject(settingsFocus), radius: 24)
            panel.onTabKey = { [weak self] in
                self?.settingsFocus.advance(reverse: false)
            }
            panel.onShiftTabKey = { [weak self] in
                self?.settingsFocus.advance(reverse: true)
            }
            panel.onEnterKey = { [weak self] in
                self?.settingsFocus.activateFocused() ?? false
            }
            panel.onCloseKey = { [weak self] in
                self?.hideSettings(focusMain: true)
            }
            panel.onCommandSKey = { [weak self] in
                self?.hideSettings(focusMain: true)
            }
            settingsPanel = panel
        }
        guard let settingsPanel else { return }
        positionSettings(settingsPanel)
        NSApp.activate(ignoringOtherApps: true)
        settingsPanel.makeKeyAndOrderFront(nil)
        settingsPanel.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self, weak settingsPanel] in
            guard let settingsPanel else { return }
            settingsPanel.makeKeyAndOrderFront(nil)
            settingsPanel.makeFirstResponder(settingsPanel.contentView)
            self?.settingsFocus.focusFirst()
        }
    }

    func hideSettings(focusMain: Bool = false) {
        settingsPanel?.orderOut(nil)
        state?.showSettings = false
        if focusMain { focusMainEditor() }
    }

    func toggleSettings() {
        if settingsPanel?.isVisible == true { hideSettings(focusMain: true) } else { showSettings() }
    }

    func showCandidates() {
        guard let state else { return }
        if candidatesPanel == nil {
            let panel = makePanel(width: 900, height: 230, minWidth: 240, minHeight: 140, radius: 18)
            panel.contentView = roundedHostingView(rootView: CandidateOverlayWindowView().environmentObject(state), radius: 18)
            panel.onTabKey = { [weak state] in
                guard let state else { return }
                state.candidateResults.isEmpty ? state.nextLauncherMode() : state.nextCandidate()
            }
            panel.onShiftTabKey = { [weak state] in
                guard let state else { return }
                state.candidateResults.isEmpty ? state.previousLauncherMode() : state.previousCandidate()
            }
            panel.onEnterKey = { [weak state] in
                guard let state else { return false }
                if state.candidateResults.isEmpty {
                    Task { await state.runSelectedLauncherMode() }
                } else {
                    state.restoreSelectedCandidateToEditor()
                }
                return true
            }
            panel.onCloseKey = { [weak self] in
                self?.hideCandidates(focusMain: true)
            }
            panel.onToggleCandidatesKey = { [weak self] in
                self?.hideCandidates(focusMain: true)
            }
            candidatesPanel = panel
        }
        guard let candidatesPanel else { return }
        positionCandidates(candidatesPanel)
        NSApp.activate(ignoringOtherApps: true)
        candidatesPanel.makeKeyAndOrderFront(nil)
        candidatesPanel.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak candidatesPanel] in
            candidatesPanel?.makeKeyAndOrderFront(nil)
            candidatesPanel?.makeFirstResponder(candidatesPanel?.contentView)
        }
    }

    func hideCandidates() {
        candidatesPanel?.orderOut(nil)
    }

    func hideCandidates(focusMain: Bool) {
        candidatesPanel?.orderOut(nil)
        state?.showCandidateOverlay = false
        if focusMain { focusMainEditor() }
    }

    func setCandidatesVisible(_ visible: Bool) {
        visible ? showCandidates() : hideCandidates(focusMain: true)
    }

    func showImportPrompt() {
        guard let state else { return }
        if importPromptPanel == nil {
            let panel = makePanel(width: 460, height: 92, minWidth: 340, minHeight: 78, radius: 18)
            panel.contentView = roundedHostingView(rootView: ImportConfirmWindowView().environmentObject(state), radius: 18)
            panel.onEnterKey = { [weak state] in
                state?.confirmPendingImport()
                return true
            }
            panel.onCloseKey = { [weak state] in
                state?.cancelPendingImport()
            }
            panel.onCommandSKey = { [weak state] in
                state?.cancelPendingImport()
            }
            importPromptPanel = panel
        }
        guard let importPromptPanel else { return }
        positionImportPrompt(importPromptPanel)
        NSApp.activate(ignoringOtherApps: true)
        importPromptPanel.makeKeyAndOrderFront(nil)
        importPromptPanel.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak importPromptPanel] in
            importPromptPanel?.makeKeyAndOrderFront(nil)
            importPromptPanel?.makeFirstResponder(importPromptPanel?.contentView)
        }
    }

    func hideImportPrompt(focusMain: Bool) {
        importPromptPanel?.orderOut(nil)
        if focusMain { focusMainEditor() }
    }

    func setImportPromptVisible(_ visible: Bool) {
        visible ? showImportPrompt() : hideImportPrompt(focusMain: true)
    }

    func repositionCandidatesIfVisible() {
        if candidatesPanel?.isVisible == true, let candidatesPanel {
            positionCandidates(candidatesPanel)
        }
        if importPromptPanel?.isVisible == true, let importPromptPanel {
            positionImportPrompt(importPromptPanel)
        }
    }

    private func makePanel(width: CGFloat, height: CGFloat, minWidth: CGFloat, minHeight: CGFloat, radius: CGFloat) -> KeyableAuxiliaryPanel {
        let panel = KeyableAuxiliaryPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.minSize = NSSize(width: minWidth, height: minHeight)
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        return panel
    }

    private func focusFirstControl(in panel: NSPanel) {
        focusNextControl(in: panel, reverse: false, wrapFromCurrent: false)
    }

    private func focusNextControl(in panel: NSPanel?, reverse: Bool, wrapFromCurrent: Bool = true) {
        guard let panel, let contentView = panel.contentView else { return }
        let controls = focusableControls(in: contentView)
        guard !controls.isEmpty else {
            panel.makeFirstResponder(contentView)
            return
        }

        let current = currentFocusedControl(in: panel, controls: controls)
        let nextIndex: Int
        if wrapFromCurrent, let current, let index = controls.firstIndex(of: current) {
            nextIndex = (index + (reverse ? -1 : 1) + controls.count) % controls.count
        } else {
            nextIndex = reverse ? controls.count - 1 : 0
        }
        panel.makeFirstResponder(controls[nextIndex])
    }

    private func focusableControls(in view: NSView) -> [NSView] {
        var result: [NSView] = []
        if isFocusableControl(view) {
            result.append(view)
        }
        for subview in view.subviews {
            result.append(contentsOf: focusableControls(in: subview))
        }
        return result
    }

    private func isFocusableControl(_ view: NSView) -> Bool {
        guard !view.isHidden, view.alphaValue > 0.01 else { return false }
        if let control = view as? NSControl {
            return control.isEnabled && (control is NSButton || control is NSTextField || control is NSPopUpButton || control is NSSegmentedControl)
        }
        if let textView = view as? NSTextView {
            return textView.isEditable || textView.isSelectable
        }
        return false
    }

    private func currentFocusedControl(in panel: NSPanel, controls: [NSView]) -> NSView? {
        if let responder = panel.firstResponder as? NSView {
            if let direct = controls.first(where: { $0 === responder }) {
                return direct
            }
            if let descendant = controls.first(where: { responder.isDescendant(of: $0) || $0.isDescendant(of: responder) }) {
                return descendant
            }
            if let fieldEditor = responder as? NSTextView, let delegateView = fieldEditor.delegate as? NSView {
                return controls.first(where: { $0 === delegateView || delegateView.isDescendant(of: $0) || $0.isDescendant(of: delegateView) })
            }
        }
        return nil
    }

    private func focusMainEditor() {
        guard let mainPanel else { return }
        NSApp.activate(ignoringOtherApps: true)
        mainPanel.makeKeyAndOrderFront(nil)
        if let editor = mainPanel.contentView?.firstSubview(of: KeyHandlingTextView.self) {
            mainPanel.makeFirstResponder(editor)
        } else {
            mainPanel.makeFirstResponder(mainPanel.contentView)
        }
    }

    private func roundedHostingView<Content: View>(rootView: Content, radius: CGFloat) -> NSHostingView<Content> {
        let view = NSHostingView(rootView: rootView)
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.masksToBounds = true
        return view
    }

    private func positionSettings(_ panel: NSPanel) {
        guard let screen = mainPanel?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: false)
    }

    private func positionCandidates(_ panel: NSPanel) {
        guard let mainPanel else { return }
        let screen = mainPanel.screen ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let main = mainPanel.frame
        let horizontalPadding: CGFloat = visible.width < 420 ? 12 : 24
        let width = min(max(240, visible.width - horizontalPadding * 2), max(1, visible.width - 8))
        let height = max(154, min(230, visible.height * 0.24))
        let x = visible.midX - width / 2
        let y = min(visible.maxY - height - 16, main.maxY + 10)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }

    private func positionImportPrompt(_ panel: NSPanel) {
        guard let mainPanel else { return }
        let screen = mainPanel.screen ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let main = mainPanel.frame
        let width = min(max(360, main.width), visible.width - 48)
        let height: CGFloat = 92
        let x = min(max(visible.minX + 24, main.midX - width / 2), visible.maxX - width - 24)
        let y = min(visible.maxY - height - 16, main.maxY + 10)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }
}


private extension NSView {
    func firstSubview(where predicate: (NSView) -> Bool) -> NSView? {
        if predicate(self) { return self }
        for subview in subviews {
            if let found = subview.firstSubview(where: predicate) { return found }
        }
        return nil
    }

    func firstSubview<T: NSView>(of type: T.Type) -> T? {
        if let view = self as? T { return view }
        for subview in subviews {
            if let found = subview.firstSubview(of: type) { return found }
        }
        return nil
    }
}
