import XCTest
@testable import RetypoAir

final class DefaultPricingTests: XCTestCase {
    func testExactKeyMatchReturnsListedPricing() {
        let result = DefaultPricing.pricing(provider: .anthropic, modelID: "claude-opus-4-7")
        XCTAssertEqual(result?.inputPerMillion, 5)
        XCTAssertEqual(result?.outputPerMillion, 25)
    }

    func testAnthropicOpusOldVersionFallsBackToHigherTier() {
        let result = DefaultPricing.pricing(provider: .anthropic, modelID: "claude-opus-4-1")
        XCTAssertEqual(result?.inputPerMillion, 15)
        XCTAssertEqual(result?.outputPerMillion, 75)
    }

    func testAnthropicSonnetMatchByPattern() {
        let result = DefaultPricing.pricing(provider: .anthropic, modelID: "claude-sonnet-99-future")
        XCTAssertEqual(result?.inputPerMillion, 3)
        XCTAssertEqual(result?.outputPerMillion, 15)
    }

    func testGroqGptOss20bMatchesExpectedRate() {
        let result = DefaultPricing.pricing(provider: .groq, modelID: "openai/gpt-oss-20b-distilled")
        XCTAssertEqual(result?.inputPerMillion, 0.075)
        XCTAssertEqual(result?.outputPerMillion, 0.30)
    }

    func testOpenAIMiniMatchesBeforeBaseModel() {
        let result = DefaultPricing.pricing(provider: .openai, modelID: "gpt-5-mini-future")
        XCTAssertEqual(result?.inputPerMillion, 0.25)
        XCTAssertEqual(result?.outputPerMillion, 2)
    }

    func testOpenrouterReturnsNil() {
        XCTAssertNil(DefaultPricing.pricing(provider: .openrouter, modelID: "any-model"))
    }

    func testUnknownAnthropicReturnsNil() {
        XCTAssertNil(DefaultPricing.pricing(provider: .anthropic, modelID: "claude-something-totally-new"))
    }
}
