import SwiftUI
import AppKit

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    var nativeSpellcheck: Bool
    var onSubmit: () -> Void
    var onChange: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.onChangeSelection = onChange
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = nativeSpellcheck
        textView.isGrammarCheckingEnabled = nativeSpellcheck
        textView.isAutomaticSpellingCorrectionEnabled = nativeSpellcheck
        textView.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text

        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? KeyHandlingTextView else { return }
        if textView.string != text { textView.string = text }
        textView.isContinuousSpellCheckingEnabled = nativeSpellcheck
        textView.isGrammarCheckingEnabled = nativeSpellcheck
        textView.isAutomaticSpellingCorrectionEnabled = nativeSpellcheck
        textView.onSubmit = onSubmit
        textView.onChangeSelection = onChange
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextEditor
        init(_ parent: NativeTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onChange()
        }
    }
}

final class KeyHandlingTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onChangeSelection: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { // return / keypad enter
            if event.modifierFlags.contains(.shift) {
                insertNewlineIgnoringFieldEditor(nil)
            } else {
                onSubmit?()
            }
            return
        }
        if event.keyCode == 53 { // escape
            window?.orderOut(nil)
            return
        }
        super.keyDown(with: event)
    }
}
