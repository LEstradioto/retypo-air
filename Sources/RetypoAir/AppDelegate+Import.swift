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
        if NSApp.isActive {
            DebugLog.log("import skipped because Retypo is active; running all modes")
            Task { [weak state] in await state?.runAllEnabledModes() }
            return
        }
        guard let sourceApplication = resolveExternalSource() else { return }
        previousApplication = sourceApplication
        let sourceName = sourceApplication.localizedName ?? "frontmost app"
        DebugLog.log("import source name=\(sourceName) bundle=\(sourceApplication.bundleIdentifier ?? "nil") pid=\(sourceApplication.processIdentifier)")
        let trusted = requestAccessibilityTrustIfNeeded()
        DebugLog.log("accessibility trusted=\(trusted)")
        if trusted, importViaAXSelectedText(application: sourceApplication, sourceName: sourceName) { return }
        guard allowClipboardFallback else {
            DebugLog.log("fast import found no AXSelectedText; opening panel without clipboard fallback")
            showPanel()
            state?.status = "No selected text imported"
            return
        }
        startClipboardPoll(sourceApplication: sourceApplication, sourceName: sourceName, trustedForAccessibility: trusted)
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
        let originalClipboard = ClipboardService.snapshot()
        let pasteboard = NSPasteboard.general
        let emptyMarker = "__RETYP_AIR_IMPORT_EMPTY_\(UUID().uuidString)__"
        pasteboard.clearContents()
        pasteboard.setString(emptyMarker, forType: .string)
        let markerChangeCount = pasteboard.changeCount

        if trustedForAccessibility, pressCopyMenuItem(in: sourceApplication) {
            DebugLog.log("copy menu pressed via AX")
            completeSelectionImportWhenClipboardChanges(ImportPollContext(
                originalClipboard: originalClipboard,
                marker: emptyMarker,
                markerChangeCount: markerChangeCount,
                sourceName: sourceName,
                trustedForAccessibility: trustedForAccessibility,
                deadline: Date().addingTimeInterval(0.9)
            ))
        } else {
            DebugLog.log("copy menu unavailable; not sending synthetic cmd+c to avoid leaking literal c")
            ClipboardService.restore(originalClipboard)
            showPanel()
            state?.status = trustedForAccessibility ? "No selected text imported" : "Grant Accessibility permission to import selection"
        }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.completeSelectionImportWhenClipboardChanges(ctx)
            }
            return
        }

        ClipboardService.restore(ctx.originalClipboard)
        let text = imported.trimmingCharacters(in: .newlines)
        guard changed, !text.isEmpty, !isMarker else {
            DebugLog.log("import failed: clipboard did not contain selected text")
            showPanel()
            let permissionHint = ctx.trustedForAccessibility ? "" : " Grant Accessibility permission to Retypo Air, then try again."
            state?.status = "No selected text imported.\(permissionHint)"
            return
        }

        DebugLog.log("import success via clipboard length=\(imported.count)")
        let needsConfirmation = state?.receiveExternalImport(imported, source: ctx.sourceName) ?? false
        showPanel()
        if needsConfirmation { auxiliaryPanels?.setImportPromptVisible(true) }
    }
}
