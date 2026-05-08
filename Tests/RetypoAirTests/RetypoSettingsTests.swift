import XCTest
@testable import RetypoAir

final class RetypoSettingsTests: XCTestCase {
    func testExperimentalVSCodeAccessibleViewDefaultsToFalse() {
        XCTAssertFalse(RetypoSettings().experimentalVSCodeAccessibleViewImport)
    }

    func testExperimentalVSCodeAccessibleViewDecodesWhenExplicitlyEnabled() throws {
        let data = Data(#"{"experimentalVSCodeAccessibleViewImport":true}"#.utf8)
        let settings = try JSONDecoder().decode(RetypoSettings.self, from: data)
        XCTAssertTrue(settings.experimentalVSCodeAccessibleViewImport)
    }
}
