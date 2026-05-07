import XCTest
@testable import RetypoAir

final class CorrectionPolicyTests: XCTestCase {
    func testTooShortReturnsFalse() {
        XCTAssertFalse(CorrectionPolicy.shouldAutoCorrect("hi"))
    }

    func testTooLongReturnsFalse() {
        let huge = String(repeating: "a", count: 6_001)
        XCTAssertFalse(CorrectionPolicy.shouldAutoCorrect(huge))
    }

    func testNormalProseReturnsTrue() {
        XCTAssertTrue(CorrectionPolicy.shouldAutoCorrect("This is a normal sentence with text"))
    }

    func testCodeFencesAreSkipped() {
        XCTAssertFalse(CorrectionPolicy.shouldAutoCorrect("Here is code:\n```\nlet x = 1\n```"))
    }

    func testShellCommandsAreSkipped() {
        XCTAssertTrue(CorrectionPolicy.looksLikeShellCommand("git push origin main"))
        XCTAssertTrue(CorrectionPolicy.looksLikeShellCommand("npm install --save-dev"))
        XCTAssertFalse(CorrectionPolicy.looksLikeShellCommand("This sentence starts with a regular word"))
    }

    func testHighSymbolDensitySkipped() {
        XCTAssertFalse(CorrectionPolicy.shouldAutoCorrect("(((!!!@@@###))) %%%%% &&&&&"))
    }

    func testWhitespaceOnlyTooShort() {
        XCTAssertFalse(CorrectionPolicy.shouldAutoCorrect("        "))
    }

    func testExactlyEightCharsAccepted() {
        XCTAssertTrue(CorrectionPolicy.shouldAutoCorrect("12345678"))
    }

    func testCommandPrefixDoesNotTriggerOnPlainProse() {
        XCTAssertFalse(CorrectionPolicy.looksLikeShellCommand("Cycling through git history is useful."))
    }
}
