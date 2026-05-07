import AppKit
import SwiftUI

extension AuxiliaryPanelController {
    func showCandidates() {
        guard let state else { return }
        if candidatesPanel == nil { candidatesPanel = makeCandidatesPanel(state: state) }
        guard let candidatesPanel else { return }
        positionCandidates(candidatesPanel)
        presentPanel(candidatesPanel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak candidatesPanel] in
            candidatesPanel?.makeKeyAndOrderFront(nil)
            candidatesPanel?.makeFirstResponder(candidatesPanel?.contentView)
        }
    }

    func hideCandidates(focusMain: Bool = false) {
        candidatesPanel?.orderOut(nil)
        state?.showCandidateOverlay = false
        if focusMain { focusMainEditor() }
    }

    func setCandidatesVisible(_ visible: Bool) {
        visible ? showCandidates() : hideCandidates(focusMain: true)
    }

    private func makeCandidatesPanel(state: AppState) -> KeyableAuxiliaryPanel {
        let panel = makePanel(width: 900, height: 230, minWidth: 240, minHeight: 140)
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
            candidateEnterAction(for: state)
        }
        panel.onCloseKey = { [weak self, weak state] in
            if let state, !state.candidateResults.isEmpty {
                state.clearCandidateResults()
            } else {
                self?.hideCandidates(focusMain: true)
            }
        }
        panel.onToggleCandidatesKey = { [weak self] in self?.hideCandidates(focusMain: true) }
        return panel
    }
}

@MainActor
private func candidateEnterAction(for state: AppState?) -> Bool {
    guard let state else { return false }
    if state.candidateResults.isEmpty {
        Task { await state.runSelectedLauncherMode() }
    } else {
        state.restoreSelectedCandidateToEditor()
    }
    return true
}
