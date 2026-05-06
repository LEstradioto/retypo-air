import AppKit
import ApplicationServices
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private var state: AppState?
    private var hotkeys: HotkeyService?
    private var auxiliaryPanels: AuxiliaryPanelController?
    private var previousApplication: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenu()
        DebugLog.log("launch bundleID=\(Bundle.main.bundleIdentifier ?? "nil") bundlePath=\(Bundle.main.bundlePath) pid=\(ProcessInfo.processInfo.processIdentifier)")

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
        appState.onImportConfirmationChanged = { [weak self] visible in
            self?.auxiliaryPanels?.setImportPromptVisible(visible)
        }

        hotkeys = HotkeyService { [weak self] action in
            switch action {
            case .togglePanel:
                self?.togglePanel()
            case .importSelection:
                self?.importSelectedTextFromFrontmostApp(allowClipboardFallback: true)
            }
        }
        hotkeys?.register()

        showPanel()
        Task { await appState.refreshModelsIfPossible() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

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
        } else if let frontmost = NSWorkspace.shared.frontmostApplication,
                  frontmost.processIdentifier != NSRunningApplication.current.processIdentifier {
            DebugLog.log("togglePanel from external app; attempting fast selected-text import before show")
            importSelectedTextFromFrontmostApp(allowClipboardFallback: false)
        } else {
            showPanel()
        }
    }

    private func importSelectedTextFromFrontmostApp(allowClipboardFallback: Bool) {
        DebugLog.log("import begin nsAppActive=\(NSApp.isActive)")
        if NSApp.isActive {
            DebugLog.log("import skipped because Retypo is active; running all modes")
            Task { [weak state] in
                await state?.runAllEnabledModes()
            }
            return
        }

        guard let sourceApplication = NSWorkspace.shared.frontmostApplication,
              sourceApplication.processIdentifier != NSRunningApplication.current.processIdentifier else {
            DebugLog.log("import failed: no external frontmost app. frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
            showPanel()
            state?.status = "No external app focused"
            return
        }

        previousApplication = sourceApplication
        let sourceName = sourceApplication.localizedName ?? "frontmost app"
        DebugLog.log("import source name=\(sourceName) bundle=\(sourceApplication.bundleIdentifier ?? "nil") pid=\(sourceApplication.processIdentifier)")
        let trustedForAccessibility = requestAccessibilityTrustIfNeeded()
        DebugLog.log("accessibility trusted=\(trustedForAccessibility)")

        if trustedForAccessibility,
           let selectedText = selectedTextViaAccessibility(from: sourceApplication),
           !selectedText.trimmingCharacters(in: .newlines).isEmpty {
            DebugLog.log("import success via AXSelectedText length=\(selectedText.count)")
            let needsConfirmation = state?.receiveExternalImport(selectedText, source: sourceName) ?? false
            showPanel()
            if needsConfirmation { auxiliaryPanels?.setImportPromptVisible(true) }
            return
        }

        guard allowClipboardFallback else {
            DebugLog.log("fast import found no AXSelectedText; opening panel without clipboard fallback")
            showPanel()
            state?.status = "No selected text imported"
            return
        }

        let originalClipboard = ClipboardService.snapshot()
        let pasteboard = NSPasteboard.general
        let emptyMarker = "__RETYP_AIR_IMPORT_EMPTY_\(UUID().uuidString)__"
        pasteboard.clearContents()
        pasteboard.setString(emptyMarker, forType: .string)
        let markerChangeCount = pasteboard.changeCount

        if trustedForAccessibility, pressCopyMenuItem(in: sourceApplication) {
            DebugLog.log("copy menu pressed via AX")
            completeSelectionImportWhenClipboardChanges(
                originalClipboard: originalClipboard,
                marker: emptyMarker,
                markerChangeCount: markerChangeCount,
                sourceName: sourceName,
                trustedForAccessibility: trustedForAccessibility,
                deadline: Date().addingTimeInterval(0.9)
            )
        } else {
            DebugLog.log("copy menu unavailable; not sending synthetic cmd+c to avoid leaking literal c")
            ClipboardService.restore(originalClipboard)
            showPanel()
            state?.status = trustedForAccessibility ? "No selected text imported" : "Grant Accessibility permission to import selection"
        }
    }

    private func rememberPreviousApplication() {
        let current = NSWorkspace.shared.frontmostApplication
        if current?.processIdentifier != NSRunningApplication.current.processIdentifier {
            previousApplication = current
        }
    }

    private func requestAccessibilityTrustIfNeeded() -> Bool {
        let before = AXIsProcessTrusted()
        DebugLog.log("accessibility trusted before prompt=\(before)")
        if before { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let after = AXIsProcessTrustedWithOptions(options)
        DebugLog.log("accessibility trusted after prompt call=\(after)")
        return after
    }

    private func selectedTextViaAccessibility(from application: NSRunningApplication) -> String? {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let focused = axAttribute(appElement, kAXFocusedUIElementAttribute) as AXUIElement? else {
            DebugLog.log("AXSelectedText failed: no focused UI element")
            return nil
        }
        if let selected = axAttribute(focused, kAXSelectedTextAttribute) as String?,
           !selected.isEmpty {
            return selected
        }
        DebugLog.log("AXSelectedText empty or unavailable")
        return nil
    }

    private func pressCopyMenuItem(in application: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let menuBar = axAttribute(appElement, kAXMenuBarAttribute) as AXUIElement? else {
            DebugLog.log("AX menu bar unavailable")
            return false
        }
        if let exact = findMenuItem(in: menuBar, titleMatches: ["Copy", "Copiar"], maxDepth: 6),
           isAXEnabled(exact) {
            let result = AXUIElementPerformAction(exact, kAXPressAction as CFString)
            DebugLog.log("AX press Copy title result=\(result.rawValue)")
            return result == .success
        }
        if let commandC = findMenuItem(in: menuBar, commandCharacter: "C", maxDepth: 6),
           isAXEnabled(commandC) {
            let result = AXUIElementPerformAction(commandC, kAXPressAction as CFString)
            DebugLog.log("AX press Copy command result=\(result.rawValue)")
            return result == .success
        }
        DebugLog.log("AX copy menu item not found/enabled")
        return false
    }

    private func findMenuItem(in element: AXUIElement, titleMatches titles: Set<String>, maxDepth: Int) -> AXUIElement? {
        guard maxDepth >= 0 else { return nil }
        if let title = axAttribute(element, kAXTitleAttribute) as String?,
           titles.contains(title) {
            return element
        }
        for child in axChildren(of: element) {
            if let found = findMenuItem(in: child, titleMatches: titles, maxDepth: maxDepth - 1) {
                return found
            }
        }
        return nil
    }

    private func findMenuItem(in element: AXUIElement, commandCharacter: String, maxDepth: Int) -> AXUIElement? {
        guard maxDepth >= 0 else { return nil }
        if let command = axAttribute(element, kAXMenuItemCmdCharAttribute) as String?,
           command.caseInsensitiveCompare(commandCharacter) == .orderedSame {
            return element
        }
        for child in axChildren(of: element) {
            if let found = findMenuItem(in: child, commandCharacter: commandCharacter, maxDepth: maxDepth - 1) {
                return found
            }
        }
        return nil
    }

    private func axChildren(of element: AXUIElement) -> [AXUIElement] {
        guard let children = axAttribute(element, kAXChildrenAttribute) as [AXUIElement]? else { return [] }
        return children
    }

    private func isAXEnabled(_ element: AXUIElement) -> Bool {
        (axAttribute(element, kAXEnabledAttribute) as Bool?) ?? true
    }

    private func axAttribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else { return nil }
        return value as? T
    }

    private func completeSelectionImportWhenClipboardChanges(
        originalClipboard: ClipboardService.Snapshot,
        marker: String,
        markerChangeCount: Int,
        sourceName: String,
        trustedForAccessibility: Bool,
        deadline: Date
    ) {
        let pasteboard = NSPasteboard.general
        let imported = pasteboard.string(forType: .string) ?? ""
        let isMarker = imported.hasPrefix("__RETYP_AIR_IMPORT_EMPTY_")
        let changed = pasteboard.changeCount != markerChangeCount || !isMarker
        DebugLog.log("clipboard poll changed=\(changed) changeCount=\(pasteboard.changeCount) markerChangeCount=\(markerChangeCount) importedLen=\(imported.count)")

        if !changed, Date() < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.completeSelectionImportWhenClipboardChanges(
                    originalClipboard: originalClipboard,
                    marker: marker,
                    markerChangeCount: markerChangeCount,
                    sourceName: sourceName,
                    trustedForAccessibility: trustedForAccessibility,
                    deadline: deadline
                )
            }
            return
        }

        ClipboardService.restore(originalClipboard)
        let text = imported.trimmingCharacters(in: .newlines)
        guard changed, !text.isEmpty, !isMarker else {
            DebugLog.log("import failed: clipboard did not contain selected text")
            showPanel()
            let permissionHint = trustedForAccessibility ? "" : " Grant Accessibility permission to Retypo Air, then try again."
            state?.status = "No selected text imported.\(permissionHint)"
            return
        }

        DebugLog.log("import success via clipboard length=\(imported.count)")
        let needsConfirmation = state?.receiveExternalImport(imported, source: sourceName) ?? false
        showPanel()
        if needsConfirmation { auxiliaryPanels?.setImportPromptVisible(true) }
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

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Retypo Air")
        let quitItem = NSMenuItem(title: "Quit Retypo Air", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
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
