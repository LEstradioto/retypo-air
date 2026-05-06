import SwiftUI

struct CandidateOverlayWindowView: View {
    @EnvironmentObject private var state: AppState
    private let cardSpacing: CGFloat = 10

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
                .lineLimit(1)
                .truncationMode(.tail)
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
        GeometryReader { proxy in
            let width = responsiveCardWidth(
                available: proxy.size.width,
                count: state.enabledActions.count,
                preferred: 220,
                minimum: 160
            )
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: cardSpacing) {
                        ForEach(Array(state.enabledActions.enumerated()), id: \.element.id) { index, action in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(action.title)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .lineLimit(1)
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
                            .id(action.id)
                            .padding(10)
                            .frame(width: width, height: 142)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(index == state.selectedLauncherModeIndex ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(index == state.selectedLauncherModeIndex ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1))
                            .onTapGesture { state.selectedLauncherModeIndex = index; state.setCurrentAction(action.id) }
                            .pointingCursor()
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: proxy.size.width, alignment: .leading)
                    .padding(.bottom, 2)
                }
                .onAppear { scrollToSelectedLauncher(using: scrollProxy) }
                .onChange(of: state.selectedLauncherModeIndex) { _ in
                    scrollToSelectedLauncher(using: scrollProxy)
                }
                .onChange(of: state.enabledActions.count) { _ in
                    scrollToSelectedLauncher(using: scrollProxy)
                }
            }
        }
        .frame(height: 146)
    }

    private var candidates: some View {
        GeometryReader { proxy in
            let width = responsiveCardWidth(
                available: proxy.size.width,
                count: state.candidateResults.count,
                preferred: 260,
                minimum: 180
            )
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: cardSpacing) {
                        ForEach(Array(state.candidateResults.enumerated()), id: \.element.id) { index, candidate in
                            CandidateCard(candidate: candidate, selected: index == state.selectedCandidateIndex) {
                                state.selectCandidate(at: index)
                            } apply: {
                                state.selectedCandidateIndex = index
                                state.restoreSelectedCandidateToEditor()
                            }
                            .id(candidate.id)
                            .frame(width: width)
                        }
                    }
                    .frame(minWidth: proxy.size.width, alignment: .leading)
                    .padding(.bottom, 2)
                }
                .onAppear { scrollToSelectedCandidate(using: scrollProxy) }
                .onChange(of: state.selectedCandidateIndex) { _ in
                    scrollToSelectedCandidate(using: scrollProxy)
                }
                .onChange(of: state.candidateResults.count) { _ in
                    scrollToSelectedCandidate(using: scrollProxy)
                }
            }
        }
        .frame(height: 178)
    }

    private func responsiveCardWidth(available: CGFloat, count: Int, preferred: CGFloat, minimum: CGFloat) -> CGFloat {
        let available = max(1, available)
        guard count > 0 else { return min(preferred, available) }
        let visibleColumns: Int
        if available < 420 {
            visibleColumns = 1
        } else if available < 760 {
            visibleColumns = min(2, count)
        } else {
            visibleColumns = min(3, count)
        }
        let usable = available - CGFloat(max(0, visibleColumns - 1)) * cardSpacing
        let calculated = usable / CGFloat(max(1, visibleColumns))
        let clamped = min(preferred, max(minimum, calculated))
        return min(clamped, available)
    }

    private func scrollToSelectedLauncher(using proxy: ScrollViewProxy) {
        guard state.enabledActions.indices.contains(state.selectedLauncherModeIndex) else { return }
        let id = state.enabledActions[state.selectedLauncherModeIndex].id
        scrollTo(id, using: proxy)
    }

    private func scrollToSelectedCandidate(using proxy: ScrollViewProxy) {
        guard state.candidateResults.indices.contains(state.selectedCandidateIndex) else { return }
        let id = state.candidateResults[state.selectedCandidateIndex].id
        scrollTo(id, using: proxy)
    }

    private func scrollTo<ID: Hashable>(_ id: ID, using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.16)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
}
