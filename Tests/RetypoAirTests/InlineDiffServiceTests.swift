import XCTest
@testable import RetypoAir

final class InlineDiffServiceTests: XCTestCase {
    func testIdenticalTextHasNoChanges() {
        let ranges = InlineDiffService.changedRanges(original: "hello world", corrected: "hello world")
        XCTAssertTrue(ranges.isEmpty)
    }

    func testEmptyCorrectedReturnsNoChanges() {
        let ranges = InlineDiffService.changedRanges(original: "anything", corrected: "")
        XCTAssertTrue(ranges.isEmpty)
    }

    func testSingleWordReplacementMarksOnlyChangedToken() {
        let count = InlineDiffService.changedWordCount(original: "the cat sat", corrected: "the dog sat")
        XCTAssertEqual(count, 1)
    }

    func testInsertedWordCountedAsChange() {
        let count = InlineDiffService.changedWordCount(original: "the sat", corrected: "the cat sat")
        XCTAssertEqual(count, 1)
    }

    func testFullReplacementMergesAdjacentChanges() {
        // mergeNearby collapses changes ≤ 2 chars apart into one range.
        let count = InlineDiffService.changedWordCount(original: "alpha", corrected: "bravo charlie")
        XCTAssertEqual(count, 1)
    }

    func testDistantChangesStayAsTwoRanges() {
        let count = InlineDiffService.changedWordCount(
            original: "the cat sat on the mat",
            corrected: "the dog sat on the rug"
        )
        XCTAssertEqual(count, 2)
    }
}
