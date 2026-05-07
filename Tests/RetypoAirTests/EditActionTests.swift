import XCTest
@testable import RetypoAir

final class EditActionTests: XCTestCase {
    func testDefaultsContainCorrectAction() {
        XCTAssertEqual(EditAction.defaults.first?.id, "correct")
    }

    func testDefaultsAllEnabled() {
        XCTAssertTrue(EditAction.defaults.allSatisfy(\.isEnabled))
    }

    func testDefaultsHaveUniqueIDs() {
        let ids = EditAction.defaults.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testCodableRoundTrip() throws {
        let original = EditAction(id: "x", title: "X", instruction: "do x", isEnabled: false)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditAction.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
}
