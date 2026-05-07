import SwiftUI

struct RetypoView: View {
    @EnvironmentObject var state: AppState

    var isLighter: Bool { state.settings.mainTheme == .lighter }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Color.clear.frame(height: isLighter ? 6 : 8)
                if state.settings.editorLayout == .stacked {
                    stackedEditor
                } else {
                    inlineEditor
                }
                footerStatus
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isLighter ? 16 : 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isLighter ? 18 : 24, style: .continuous)
                .strokeBorder(Color.white.opacity(isLighter ? 0.10 : 0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var background: some View {
        if isLighter {
            Color.clear.ignoresSafeArea()
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .ignoresSafeArea()
        } else {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.white.opacity(0.13), Color.black.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    var statColor: Color {
        Color.secondary.opacity(isLighter ? 0.74 : 0.98)
    }

    private var stackedEditor: some View {
        VStack(spacing: isLighter ? 6 : 8) {
            editorBox(minHeight: 44)
            outputBox
        }
        .padding(.horizontal, isLighter ? 6 : 8)
        .padding(.bottom, isLighter ? 1 : 2)
    }

    private var inlineEditor: some View {
        editorBox(minHeight: 72)
            .padding(.horizontal, isLighter ? 6 : 8)
            .padding(.bottom, isLighter ? 1 : 2)
    }

    private func editorBox(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            NativeTextEditor(
                text: $state.inputText,
                nativeSpellcheck: state.settings.nativeSpellcheck,
                highlightRanges: state.inlineHighlightRanges,
                lighter: isLighter,
                onSubmit: { Task { await state.runCurrentAction(source: "enter") } },
                onRunAll: { Task { await state.runAllEnabledModes() } },
                onChange: { state.onInputChanged() },
                onCancel: { state.requestHide() },
                onTab: { if state.showCandidateOverlay { state.candidateResults.isEmpty ? state.nextLauncherMode() : state.nextCandidate(); return true }; if state.footerFocusIndex != nil { state.nextFooterFocus(); return true }; return false },
                onShiftTab: { if state.showCandidateOverlay { state.candidateResults.isEmpty ? state.previousLauncherMode() : state.previousCandidate(); return true }; if state.footerFocusIndex != nil { state.previousFooterFocus(); return true }; return false },
                onFocusCycle: { state.cycleFooterFocus() },
                onEnterInOverlay: { if state.footerFocusIndex != nil { state.activateFooterFocus(); return true }; if state.showCandidateOverlay, state.candidateResults.isEmpty { Task { await state.runSelectedLauncherMode() }; return true }; return false },
                onToggleOverlay: { state.toggleCandidateOverlay() },
                onSettings: { state.requestSettings() },
                onUndo: { state.undoEditorChange() },
                onRedo: { state.redoEditorChange() },
                onShortcut: { state.handleShortcut($0) }
            )
            .frame(minHeight: minHeight)
            .background(editorBackground)
            .overlay(editorStroke)
        }
    }

    private var editorBackground: some View {
        RoundedRectangle(cornerRadius: isLighter ? 12 : 15, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor).opacity(isLighter ? 0.14 : 0.54))
            .shadow(color: .black.opacity(isLighter ? 0.025 : 0.08), radius: isLighter ? 8 : 20, x: 0, y: isLighter ? 6 : 14)
    }

    private var editorStroke: some View {
        RoundedRectangle(cornerRadius: isLighter ? 12 : 15, style: .continuous)
            .strokeBorder(Color.white.opacity(isLighter ? 0.08 : 0.12), lineWidth: 1)
    }

    private var outputBox: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text("Result")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy") { state.copyOutput() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .disabled(state.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ScrollView {
                Text(state.diffText.isEmpty ? "Set model in Settings. Type, Enter." : state.diffText)
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(state.diffText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(minHeight: 30, maxHeight: 76)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.black.opacity(0.065)))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        }
    }
}
