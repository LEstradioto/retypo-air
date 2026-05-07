import Foundation

extension AppState {
    func cycleFooterFocus() {
        if let index = footerFocusIndex {
            let next = index + 1
            footerFocusIndex = next >= footerFocusItemCount ? nil : next
            status = footerFocusIndex == nil ? "Editor" : "Footer focus"
        } else {
            footerFocusIndex = 0
            status = "Footer focus"
        }
    }

    func nextFooterFocus() {
        cycleFooterFocus()
    }

    func previousFooterFocus() {
        if let index = footerFocusIndex {
            let previous = index - 1
            footerFocusIndex = previous < 0 ? nil : previous
            status = footerFocusIndex == nil ? "Editor" : "Footer focus"
        } else {
            footerFocusIndex = footerFocusItemCount - 1
            status = "Footer focus"
        }
    }

    func activateFooterFocus() {
        guard let index = footerFocusIndex else { return }
        switch index {
        case 0:
            if let currentIndex = enabledActions.firstIndex(where: { $0.id == currentAction.id }) {
                let next = enabledActions[(currentIndex + 1) % enabledActions.count]
                setCurrentAction(next.id)
            }
        case 1:
            selectAdjacentModel(direction: 1)
        case 2:
            settings.editorLayout = settings.editorLayout == .stacked ? .inline : .stacked
            saveSettings()
        case 3:
            settings.autoCorrect.toggle()
            saveSettings()
        case 4:
            requestSettings()
        case 5:
            _ = undoEditorChange()
        case 6:
            _ = redoEditorChange()
        case 7:
            toggleCandidateOverlay()
        case 8:
            status = "Last \(lastCostLabel) · Session \(sessionCostLabel) · Today \(dayCostLabel)"
        default:
            break
        }
    }

    func nextLauncherMode() {
        moveLauncherMode(direction: 1)
    }

    func previousLauncherMode() {
        moveLauncherMode(direction: -1)
    }

    func moveLauncherMode(direction: Int) {
        guard !enabledActions.isEmpty else { return }
        selectedLauncherModeIndex = (selectedLauncherModeIndex + direction + enabledActions.count) % enabledActions.count
        settings.currentActionID = enabledActions[selectedLauncherModeIndex].id
        status = "Mode: \(currentAction.title)"
        saveSettings()
    }

    func runSelectedLauncherMode() async {
        guard enabledActions.indices.contains(selectedLauncherModeIndex) else { return }
        let action = enabledActions[selectedLauncherModeIndex]
        setCurrentAction(action.id)
        await runAction(action, source: "candidate")
        if !diffText.isEmpty {
            candidateResults = [CandidateResult(action: action, output: outputText, diff: diffText, usage: lastCost.usage, costUSD: lastCost.costUSD)]
            selectedCandidateIndex = 0
            setCandidateOverlayVisible(true)
        }
    }

    func nextCandidate() {
        moveCandidate(direction: 1)
    }

    func previousCandidate() {
        moveCandidate(direction: -1)
    }

    func moveCandidate(direction: Int) {
        guard !candidateResults.isEmpty else { return }
        selectedCandidateIndex = (selectedCandidateIndex + direction + candidateResults.count) % candidateResults.count
        selectCandidate(at: selectedCandidateIndex)
    }

    func selectCandidate(at index: Int) {
        guard candidateResults.indices.contains(index) else { return }
        selectedCandidateIndex = index
        let candidate = candidateResults[index]
        outputText = candidate.output
        diffText = candidate.diff
        ClipboardService.copy(candidate.output)
        status = "Selected \(candidate.action.title)"
    }

    func restoreSelectedCandidateToEditor() {
        guard candidateResults.indices.contains(selectedCandidateIndex) else { return }
        pushEditorUndoSnapshot()
        inputText = candidateResults[selectedCandidateIndex].output
        DraftStore.save(inputText)
        setCandidateOverlayVisible(false)
        status = "Applied candidate"
    }

    func selectAdjacentModel(direction: Int) {
        let models = navigableModels
        guard !models.isEmpty else { return }
        let current = selectedModel
        let currentIndex = models.firstIndex { $0.id == current } ?? 0
        let nextIndex = (currentIndex + direction + models.count) % models.count
        setSelectedModel(models[nextIndex].id)
    }
}
