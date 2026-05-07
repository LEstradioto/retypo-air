import XCTest
@testable import RetypoAir

final class ProviderKindTests: XCTestCase {
    func testAllCasesIncludeFourProviders() {
        XCTAssertEqual(ProviderKind.allCases.count, 4)
        XCTAssertTrue(ProviderKind.allCases.contains(.groq))
        XCTAssertTrue(ProviderKind.allCases.contains(.anthropic))
        XCTAssertTrue(ProviderKind.allCases.contains(.openai))
        XCTAssertTrue(ProviderKind.allCases.contains(.openrouter))
    }

    func testDisplayNames() {
        XCTAssertEqual(ProviderKind.groq.displayName, "Groq")
        XCTAssertEqual(ProviderKind.anthropic.displayName, "Anthropic")
        XCTAssertEqual(ProviderKind.openai.displayName, "OpenAI")
        XCTAssertEqual(ProviderKind.openrouter.displayName, "OpenRouter")
    }

    func testApiKeyEnvironmentNames() {
        XCTAssertEqual(ProviderKind.groq.apiKeyEnvironmentName, "GROQ_API_KEY")
        XCTAssertEqual(ProviderKind.anthropic.apiKeyEnvironmentName, "ANTHROPIC_API_KEY")
        XCTAssertEqual(ProviderKind.openai.apiKeyEnvironmentName, "OPENAI_API_KEY")
        XCTAssertEqual(ProviderKind.openrouter.apiKeyEnvironmentName, "OPENROUTER_API_KEY")
    }

    func testRawValueAndIDMatch() {
        for provider in ProviderKind.allCases {
            XCTAssertEqual(provider.id, provider.rawValue)
        }
    }
}
