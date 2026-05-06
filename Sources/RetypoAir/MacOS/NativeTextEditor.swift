import SwiftUI
import AppKit

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    var nativeSpellcheck: Bool
    var highlightRanges: [NSRange] = []
    var lighter: Bool = false
    var onSubmit: () -> Void
    var onRunAll: () -> Void = {}
    var onChange: () -> Void
    var onCancel: () -> Void = {}
    var onTab: () -> Bool = { false }
    var onShiftTab: () -> Bool = { false }
    var onFocusCycle: () -> Void = {}
    var onEnterInOverlay: () -> Bool = { false }
    var onToggleOverlay: () -> Void = {}
    var onSettings: () -> Void = {}
    var onUndo: () -> Bool = { false }
    var onRedo: () -> Bool = { false }
    var onShortcut: (String) -> Bool = { _ in false }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.onRunAll = onRunAll
        textView.onCancel = onCancel
        textView.onTab = onTab
        textView.onShiftTab = onShiftTab
        textView.onFocusCycle = onFocusCycle
        textView.onEnterInOverlay = onEnterInOverlay
        textView.onToggleOverlay = onToggleOverlay
        textView.onSettings = onSettings
        textView.onUndo = onUndo
        textView.onRedo = onRedo
        textView.onShortcut = onShortcut
        configure(textView)
        textView.string = text

        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? KeyHandlingTextView else { return }
        let selected = textView.selectedRange()
        if textView.string != text {
            textView.string = text
            textView.undoManager?.removeAllActions()
            let safeLocation = min(selected.location, (text as NSString).length)
            textView.setSelectedRange(NSRange(location: safeLocation, length: 0))
        }
        textView.onSubmit = onSubmit
        textView.onRunAll = onRunAll
        textView.onCancel = onCancel
        textView.onTab = onTab
        textView.onShiftTab = onShiftTab
        textView.onFocusCycle = onFocusCycle
        textView.onEnterInOverlay = onEnterInOverlay
        textView.onToggleOverlay = onToggleOverlay
        textView.onSettings = onSettings
        textView.onUndo = onUndo
        textView.onRedo = onRedo
        textView.onShortcut = onShortcut
        configure(textView)
        applyHighlights(to: textView)
    }

    private func configure(_ textView: KeyHandlingTextView) {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = nativeSpellcheck
        textView.isGrammarCheckingEnabled = nativeSpellcheck
        textView.isAutomaticSpellingCorrectionEnabled = nativeSpellcheck
        textView.font = NSFont.monospacedSystemFont(ofSize: lighter ? 14 : 15, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: lighter ? 12 : 16, height: lighter ? 12 : 16)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
    }

    private func applyHighlights(to textView: NSTextView) {
        guard let layoutManager = textView.layoutManager else { return }
        let full = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        let color = NSColor.systemGreen.withAlphaComponent(lighter ? 0.22 : 0.28)
        let underline = NSColor.systemGreen.withAlphaComponent(lighter ? 0.45 : 0.60)
        for range in highlightRanges where NSMaxRange(range) <= full.length {
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
            layoutManager.addTemporaryAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, forCharacterRange: range)
            layoutManager.addTemporaryAttribute(.underlineColor, value: underline, forCharacterRange: range)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextEditor
        init(_ parent: NativeTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            guard !textView.hasMarkedText() else { return }
            parent.onChange()
        }
    }
}

final class KeyHandlingTextView: NSTextView {
    private static var killRing: String = ""
    var onSubmit: (() -> Void)?
    var onRunAll: (() -> Void)?
    var onCancel: (() -> Void)?
    var onTab: (() -> Bool)?
    var onShiftTab: (() -> Bool)?
    var onFocusCycle: (() -> Void)?
    var onEnterInOverlay: (() -> Bool)?
    var onToggleOverlay: (() -> Void)?
    var onSettings: (() -> Void)?
    var onUndo: (() -> Bool)?
    var onRedo: (() -> Bool)?
    var onShortcut: ((String) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if isQuit(event) {
            NSApp.terminate(nil)
            return
        }
        if handleClipboardAndUndo(event) { return }
        if handleControlLineEditing(event) { return }
        if handleOptionArrow(event) { return }
        if isSelectAll(event) {
            selectAll(nil)
            return
        }
        if handleHomeEnd(event) { return }
        if event.keyCode == 48 { // tab
            if event.modifierFlags.contains(.control) {
                onFocusCycle?()
                return
            }
            if event.modifierFlags.contains(.shift), onShiftTab?() == true { return }
            if onTab?() == true { return }
        }
        if event.keyCode == 2, event.modifierFlags.contains(.command) { // D
            onToggleOverlay?()
            return
        }
        if event.keyCode == 1, event.modifierFlags.contains(.command) { // S
            onSettings?()
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 { // return / keypad enter
            if event.modifierFlags.contains(.command), event.modifierFlags.contains(.shift) {
                onRunAll?()
            } else if onEnterInOverlay?() == true {
                return
            } else if event.modifierFlags.contains(.shift) {
                insertNewlineIgnoringFieldEditor(nil)
            } else {
                onSubmit?()
            }
            return
        }
        if event.keyCode == 53 { // escape
            onCancel?()
            return
        }
        if let shortcut = ShortcutFormatter.string(from: event), onShortcut?(shortcut) == true {
            return
        }
        super.keyDown(with: event)
    }

    private func handleClipboardAndUndo(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        switch Int(event.keyCode) {
        case 8: // C
            copy(nil)
            return true
        case 9: // V
            paste(nil)
            return true
        case 7: // X
            cut(nil)
            return true
        case 6: // Z
            if event.modifierFlags.contains(.shift) {
                if undoManager?.canRedo == true {
                    undoManager?.redo()
                } else {
                    _ = onRedo?()
                }
            } else {
                if undoManager?.canUndo == true {
                    undoManager?.undo()
                } else {
                    _ = onUndo?()
                }
            }
            return true
        case 16: // Y
            if undoManager?.canRedo == true {
                undoManager?.redo()
            } else {
                _ = onRedo?()
            }
            return true
        default:
            return false
        }
    }

    private func isQuit(_ event: NSEvent) -> Bool {
        event.keyCode == 12 && event.modifierFlags.contains(.command) // Q
    }

    private func handleControlLineEditing(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.control), !event.modifierFlags.contains(.command) else { return false }
        switch Int(event.keyCode) {
        case 32: // U
            deleteFromCaret(toBeginningOfLine: true)
            return true
        case 40: // K
            deleteFromCaret(toBeginningOfLine: false)
            return true
        case 16: // Y
            yankKillRing()
            return true
        default:
            return false
        }
    }

    private func handleOptionArrow(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.option) else { return false }
        switch Int(event.keyCode) {
        case 123: // left
            event.modifierFlags.contains(.shift) ? moveWordLeftAndModifySelection(nil) : moveWordLeft(nil)
            return true
        case 124: // right
            event.modifierFlags.contains(.shift) ? moveWordRightAndModifySelection(nil) : moveWordRight(nil)
            return true
        default:
            return false
        }
    }

    private func deleteFromCaret(toBeginningOfLine: Bool) {
        let selection = selectedRange()
        if selection.length > 0 {
            KeyHandlingTextView.killRing = (string as NSString).substring(with: selection)
            textStorage?.replaceCharacters(in: selection, with: "")
            didChangeText()
            return
        }
        let ns = string as NSString
        let location = min(selection.location, ns.length)
        let line = ns.lineRange(for: NSRange(location: location, length: 0))
        let range: NSRange
        if toBeginningOfLine {
            range = NSRange(location: line.location, length: max(0, location - line.location))
        } else {
            let lineEnd = max(line.location, line.location + line.length)
            let newlineAdjustedEnd: Int
            if lineEnd > line.location, lineEnd <= ns.length {
                let lastCharRange = NSRange(location: lineEnd - 1, length: 1)
                let lastChar = ns.substring(with: lastCharRange)
                newlineAdjustedEnd = (lastChar == "\n" || lastChar == "\r") ? lineEnd - 1 : lineEnd
            } else {
                newlineAdjustedEnd = lineEnd
            }
            range = NSRange(location: location, length: max(0, newlineAdjustedEnd - location))
        }
        guard range.length > 0 else { return }
        KeyHandlingTextView.killRing = ns.substring(with: range)
        textStorage?.replaceCharacters(in: range, with: "")
        setSelectedRange(NSRange(location: range.location, length: 0))
        didChangeText()
    }

    private func yankKillRing() {
        guard !KeyHandlingTextView.killRing.isEmpty else { return }
        insertText(KeyHandlingTextView.killRing, replacementRange: selectedRange())
    }

    private func isSelectAll(_ event: NSEvent) -> Bool {
        guard event.keyCode == 0 else { return false } // A
        return event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)
    }

    private func handleHomeEnd(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 115: // Home
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                moveToBeginningOfDocument(nil)
            } else {
                moveToBeginningOfLine(nil)
            }
            return true
        case 119: // End
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                moveToEndOfDocument(nil)
            } else {
                moveToEndOfLine(nil)
            }
            return true
        default:
            return false
        }
    }
}
