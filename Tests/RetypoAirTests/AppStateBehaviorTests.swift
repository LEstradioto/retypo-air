import XCTest
@testable import RetypoAir

@MainActor
final class MockPanelHost: PanelHost {
    var hideRequestCount = 0
    var settingsRequestCount = 0
    var alwaysOnTop: Bool?
    var candidatesVisibilityHistory: [Bool] = []
    var importConfirmationHistory: [Bool] = []

    func setAlwaysOnTop(_ enabled: Bool) { alwaysOnTop = enabled }
    func requestHide() { hideRequestCount += 1 }
    func requestSettings() { settingsRequestCount += 1 }
    func setCandidatesVisible(_ visible: Bool) { candidatesVisibilityHistory.append(visible) }
    func setImportConfirmationVisible(_ visible: Bool) { importConfirmationHistory.append(visible) }
}

@MainActor
final class AppStateBehaviorTests: XCTestCase {
    private func makeState() -> (AppState, MockPanelHost) {
        let state = AppState(settings: RetypoSettings())
        let host = MockPanelHost()
        state.host = host
        return (state, host)
    }

    func testRequestHideForwardsToHost() {
        let (state, host) = makeState()
        state.requestHide()
        XCTAssertEqual(host.hideRequestCount, 1)
    }

    func testRequestSettingsForwardsToHost() {
        let (state, host) = makeState()
        state.requestSettings()
        XCTAssertEqual(host.settingsRequestCount, 1)
    }

    func testSetCandidateOverlayVisibleNotifiesHost() {
        let (state, host) = makeState()
        state.setCandidateOverlayVisible(true)
        XCTAssertEqual(host.candidatesVisibilityHistory, [true])
        state.setCandidateOverlayVisible(false)
        XCTAssertEqual(host.candidatesVisibilityHistory, [true, false])
    }

    func testCancelPendingImportNotifiesHost() {
        let (state, host) = makeState()
        state.pendingImport = PendingImport(text: "x", source: "Test")
        state.cancelPendingImport()
        XCTAssertNil(state.pendingImport)
        XCTAssertEqual(host.importConfirmationHistory, [false])
    }

    func testConfirmPendingImportWithoutPendingIsNoop() {
        let (state, host) = makeState()
        state.confirmPendingImport()
        XCTAssertEqual(host.importConfirmationHistory, [])
    }

    /// Regression for the ESC-in-candidates fix: clearCandidateResults wipes
    /// state but does NOT ask the host to hide the panel.
    func testClearCandidateResultsDoesNotHideOverlay() {
        let (state, host) = makeState()
        state.candidateResults = [
            CandidateResult(action: EditAction.defaults[0], output: "x", diff: "− \n+ x", usage: .zero, costUSD: nil)
        ]
        state.selectedCandidateIndex = 0
        state.clearCandidateResults()
        XCTAssertTrue(state.candidateResults.isEmpty)
        XCTAssertEqual(state.selectedCandidateIndex, 0)
        // Host should not be asked to hide — that's the ESC→launcher behavior.
        XCTAssertEqual(host.hideRequestCount, 0)
        XCTAssertEqual(host.candidatesVisibilityHistory, [])
    }

    func testToggleCandidateOverlayWithEmptyDiffIsNoop() {
        let (state, host) = makeState()
        state.diffText = ""
        state.toggleCandidateOverlay()
        // candidateResults still empty, but overlay state toggled.
        XCTAssertEqual(host.candidatesVisibilityHistory, [true])
        XCTAssertTrue(state.candidateResults.isEmpty)
    }

    func testHostIsWeaklyHeld() {
        let state = AppState(settings: RetypoSettings())
        do {
            let host = MockPanelHost()
            state.host = host
            XCTAssertNotNil(state.host)
        }
        // host has gone out of scope; weak ref nils out.
        XCTAssertNil(state.host)
    }
}
