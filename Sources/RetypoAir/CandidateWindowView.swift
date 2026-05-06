import SwiftUI

struct CandidateOverlayWindowView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(colors: [Color.white.opacity(0.12), Color.black.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 8) {
            header
            if state.candidateResults.isEmpty {
                launcher
            } else {
                candidates
            }
        }
        .padding(12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(state.candidateResults.isEmpty ? "Run mode" : "Candidates")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text(state.candidateResults.isEmpty ? "Tab chooses mode · Enter runs · Cmd+Shift+Enter runs all" : "Tab selects + copies · Apply writes back")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Button { state.setCandidateOverlayVisible(false) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .pointingCursor()
        }
    }

    private var launcher: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(Array(state.enabledActions.enumerated()), id: \.element.id) { index, action in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(action.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Spacer()
                        if index == state.selectedLauncherModeIndex {
                            Text("selected")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(action.instruction)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                    Spacer()
                    Button("Run") { Task { state.selectedLauncherModeIndex = index; await state.runSelectedLauncherMode() } }
                        .buttonStyle(.borderless)
                        .pointingCursor()
                }
                .padding(10)
                .frame(width: 220, height: 142)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(index == state.selectedLauncherModeIndex ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(index == state.selectedLauncherModeIndex ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1))
                .onTapGesture { state.selectedLauncherModeIndex = index; state.setCurrentAction(action.id) }
                .pointingCursor()
            }
            Spacer(minLength: 0)
        }
    }

    private var candidates: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(state.candidateResults.enumerated()), id: \.element.id) { index, candidate in
                    CandidateCard(candidate: candidate, selected: index == state.selectedCandidateIndex) {
                        state.selectCandidate(at: index)
                    } apply: {
                        state.selectedCandidateIndex = index
                        state.restoreSelectedCandidateToEditor()
                    }
                    .frame(width: 260)
                }
            }
            .padding(.bottom, 2)
        }
    }
}
