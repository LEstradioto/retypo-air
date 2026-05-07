import Foundation
import AppKit

struct EditorSnapshot: Equatable {
    var inputText: String
    var correctedText: String
    var outputText: String
    var status: String
    var diffText: String
    var inlineHighlightRanges: [NSRange]
    var candidateResults: [CandidateResult]
    var showCandidateOverlay: Bool
    var selectedCandidateIndex: Int
    var wordsChangedLast: Int
    var lastAutoSubmittedHash: Int?
    var typingStartedAt: Date?
}

extension AppState {
    @discardableResult
    func undoEditorChange() -> Bool {
        guard let snapshot = editorUndoStack.popLast() else {
            status = "Nothing to undo"
            publishUndoRedoAvailability()
            return false
        }
        editorRedoStack.append(currentEditorSnapshot())
        restoreEditorSnapshot(snapshot)
        status = "Undone"
        publishUndoRedoAvailability()
        return true
    }

    @discardableResult
    func redoEditorChange() -> Bool {
        guard let snapshot = editorRedoStack.popLast() else {
            status = "Nothing to redo"
            publishUndoRedoAvailability()
            return false
        }
        editorUndoStack.append(currentEditorSnapshot())
        restoreEditorSnapshot(snapshot)
        status = "Redone"
        publishUndoRedoAvailability()
        return true
    }

    func pushEditorUndoSnapshot() {
        let snapshot = currentEditorSnapshot()
        guard editorUndoStack.last != snapshot else { return }
        editorUndoStack.append(snapshot)
        if editorUndoStack.count > editorUndoLimit {
            editorUndoStack.removeFirst(editorUndoStack.count - editorUndoLimit)
        }
        editorRedoStack.removeAll()
        publishUndoRedoAvailability()
    }

    func publishUndoRedoAvailability() {
        canUndoEditorChange = !editorUndoStack.isEmpty
        canRedoEditorChange = !editorRedoStack.isEmpty
    }

    fileprivate func currentEditorSnapshot() -> EditorSnapshot {
        EditorSnapshot(
            inputText: inputText,
            correctedText: correctedText,
            outputText: outputText,
            status: status,
            diffText: diffText,
            inlineHighlightRanges: inlineHighlightRanges,
            candidateResults: candidateResults,
            showCandidateOverlay: showCandidateOverlay,
            selectedCandidateIndex: selectedCandidateIndex,
            wordsChangedLast: wordsChangedLast,
            lastAutoSubmittedHash: lastAutoSubmittedHash,
            typingStartedAt: typingStartedAt
        )
    }

    fileprivate func restoreEditorSnapshot(_ snapshot: EditorSnapshot) {
        inputText = snapshot.inputText
        correctedText = snapshot.correctedText
        outputText = snapshot.outputText
        diffText = snapshot.diffText
        inlineHighlightRanges = snapshot.inlineHighlightRanges
        candidateResults = snapshot.candidateResults
        showCandidateOverlay = snapshot.showCandidateOverlay
        selectedCandidateIndex = min(snapshot.selectedCandidateIndex, max(0, candidateResults.count - 1))
        wordsChangedLast = snapshot.wordsChangedLast
        lastAutoSubmittedHash = snapshot.lastAutoSubmittedHash
        typingStartedAt = snapshot.typingStartedAt ?? Date()
        DraftStore.save(inputText)
        onCandidatesVisibilityChanged?(showCandidateOverlay)
    }
}
