import AppKit

extension AppDelegate {
    struct ImportPollContext {
        let originalClipboard: ClipboardService.Snapshot
        let marker: String
        let markerChangeCount: Int
        let sourceName: String
        let trustedForAccessibility: Bool
        let deadline: Date
    }

    func importSelectedTextFromFrontmostApp(allowClipboardFallback: Bool) {
        DebugLog.log("import begin nsAppActive=\(NSApp.isActive)")
        guard let sourceApplication = resolveExternalSource() else { return }
        previousApplication = sourceApplication
        let sourceName = sourceApplication.localizedName ?? "frontmost app"
        DebugLog.log("import source name=\(sourceName) bundle=\(sourceApplication.bundleIdentifier ?? "nil") pid=\(sourceApplication.processIdentifier)")
        let trusted = requestAccessibilityTrustIfNeeded()
        DebugLog.log("accessibility trusted=\(trusted)")
        // Priority 1: live AX selection — no clipboard touched.
        if trusted, importViaAXSelectedText(application: sourceApplication, sourceName: sourceName) { return }
        guard allowClipboardFallback else {
            if importExistingClipboard(sourceName: sourceName) { return }
            showPanel()
            state?.status = "No selected text imported"
            return
        }
        // Priority 2: synthetic Cmd+C via AX-pressed Copy menu (terminals etc.).
        // Falls through to Priority 3 (existing clipboard) on failure inside `failImport`.
        startClipboardPoll(sourceApplication: sourceApplication, sourceName: sourceName, trustedForAccessibility: trusted)
    }

    /// Priority 3 fallback: import whatever the user already has on the
    /// system clipboard. Returns true if anything was imported.
    private func importExistingClipboard(sourceName: String) -> Bool {
        let snapshot = ClipboardService.snapshot()
        guard let text = snapshot.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return false
        }
        DebugLog.log("import fallback: using existing clipboard length=\(text.count)")
        let needsConfirmation = state?.receiveExternalImport(text, source: "\(sourceName) (clipboard)") ?? false
        showPanel()
        if needsConfirmation { auxiliaryPanels?.setImportPromptVisible(true) }
        return true
    }

    private func resolveExternalSource() -> NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != NSRunningApplication.current.processIdentifier else {
            DebugLog.log("import failed: no external frontmost app. frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil")")
            showPanel()
            state?.status = "No external app focused"
            return nil
        }
        return app
    }

    private func importViaAXSelectedText(application: NSRunningApplication, sourceName: String) -> Bool {
        guard let selectedText = selectedTextViaAccessibility(from: application),
              !selectedText.trimmingCharacters(in: .newlines).isEmpty else { return false }
        DebugLog.log("import success via AXSelectedText length=\(selectedText.count)")
        let needsConfirmation = state?.receiveExternalImport(selectedText, source: sourceName) ?? false
        showPanel()
        if needsConfirmation { auxiliaryPanels?.setImportPromptVisible(true) }
        return true
    }

    private func startClipboardPoll(sourceApplication: NSRunningApplication, sourceName: String, trustedForAccessibility: Bool) {
        let snapshot = ClipboardService.snapshot()
        let marker = primeClipboardMarker()
        if trustedForAccessibility, pressCopyMenuItem(in: sourceApplication) {
            DebugLog.log("copy menu pressed via AX")
            // Show the panel immediately. Clipboard poll runs in the background
            // and fills the editor when the source app's Copy completes.
            showPanel()
            completeSelectionImportWhenClipboardChanges(ImportPollContext(
                originalClipboard: snapshot,
                marker: marker.text,
                markerChangeCount: marker.changeCount,
                sourceName: sourceName,
                trustedForAccessibility: trustedForAccessibility,
                deadline: Date().addingTimeInterval(0.4)
            ))
        } else {
            DebugLog.log("copy menu unavailable; not sending synthetic cmd+c to avoid leaking literal c")
            ClipboardService.restore(snapshot)
            showPanel()
            state?.status = trustedForAccessibility ? "No selected text imported" : "Grant Accessibility permission to import selection"
        }
    }

    private func primeClipboardMarker() -> (text: String, changeCount: Int) {
        let pasteboard = NSPasteboard.general
        let marker = "__RETYP_AIR_IMPORT_EMPTY_\(UUID().uuidString)__"
        pasteboard.clearContents()
        pasteboard.setString(marker, forType: .string)
        return (marker, pasteboard.changeCount)
    }

    func rememberPreviousApplication() {
        let current = NSWorkspace.shared.frontmostApplication
        if current?.processIdentifier != NSRunningApplication.current.processIdentifier {
            previousApplication = current
        }
    }

    private func completeSelectionImportWhenClipboardChanges(_ ctx: ImportPollContext) {
        let pasteboard = NSPasteboard.general
        let imported = pasteboard.string(forType: .string) ?? ""
        let isMarker = imported.hasPrefix("__RETYP_AIR_IMPORT_EMPTY_")
        let changed = pasteboard.changeCount != ctx.markerChangeCount || !isMarker
        DebugLog.log("clipboard poll changed=\(changed) changeCount=\(pasteboard.changeCount) markerChangeCount=\(ctx.markerChangeCount) importedLen=\(imported.count)")
        if !changed, Date() < ctx.deadline {
            scheduleClipboardPoll(ctx)
            return
        }
        ClipboardService.restore(ctx.originalClipboard)
        let text = imported.trimmingCharacters(in: .newlines)
        guard changed, !text.isEmpty, !isMarker else {
            failImport(ctx: ctx)
            return
        }
        DebugLog.log("import success via clipboard length=\(imported.count)")
        let needsConfirmation = state?.receiveExternalImport(imported, source: ctx.sourceName) ?? false
        showPanel()
        if needsConfirmation { auxiliaryPanels?.setImportPromptVisible(true) }
    }

    private func scheduleClipboardPoll(_ ctx: ImportPollContext) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.completeSelectionImportWhenClipboardChanges(ctx)
        }
    }

    private func failImport(ctx: ImportPollContext) {
        DebugLog.log("import failed: clipboard did not contain selected text")
        // Priority 3: original clipboard (snapshot taken before our synthetic
        // copy primed the marker). Use whatever the user already had.
        if let original = ctx.originalClipboard.string?.trimmingCharacters(in: .whitespacesAndNewlines), !original.isEmpty {
            DebugLog.log("import fallback: using original clipboard length=\(original.count)")
            let needsConfirmation = state?.receiveExternalImport(original, source: "\(ctx.sourceName) (clipboard)") ?? false
            showPanel()
            if needsConfirmation { auxiliaryPanels?.setImportPromptVisible(true) }
            return
        }
        showPanel()
        let hint = ctx.trustedForAccessibility ? "" : " Grant Accessibility permission to Retypo Air, then try again."
        state?.status = "No selected text imported.\(hint)"
    }
}
