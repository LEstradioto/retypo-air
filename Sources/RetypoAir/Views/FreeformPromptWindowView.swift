import SwiftUI

/// The Freeform-mode prompt overlay. Shows a single text field bound to
/// `AppState.freeformInstruction`. Pressing Enter submits and runs the
/// current action; Esc cancels.
///
/// The field auto-focuses on appear; previous instruction text is preserved
/// so the user can re-edit and re-run quickly.
struct FreeformPromptWindowView: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(colors: [Color.accentColor.opacity(0.12), Color.black.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.accentColor.opacity(0.24), lineWidth: 1))
        .onAppear { focusField() }
        .onChange(of: state.freeformPromptShowID) { _ in focusField() }
    }

    private func focusField() {
        // Two ticks: NSPanel needs to settle before SwiftUI focus takes.
        DispatchQueue.main.async {
            fieldFocused = true
            DispatchQueue.main.async { fieldFocused = true }
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor.opacity(0.9))
            TextField("Type instruction (e.g. translate to French and shorten)", text: $state.freeformInstruction)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($fieldFocused)
                .onSubmit { state.confirmFreeformPrompt() }
            Button("Cancel") { state.cancelFreeformPrompt() }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .pointingCursor()
            Button("Run") { state.confirmFreeformPrompt() }
                .buttonStyle(SettingsCapsuleButtonStyle(active: true))
                .pointingCursor()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
