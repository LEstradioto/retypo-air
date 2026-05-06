import Foundation

enum DefaultPricing {
    static let exact: [String: ModelPricing] = [
        // OpenAI text models, USD per 1M tokens (platform pricing, standard tier)
        "openai::gpt-5.2": .init(inputPerMillion: 1.75, outputPerMillion: 14.00),
        "openai::gpt-5.2-chat-latest": .init(inputPerMillion: 1.75, outputPerMillion: 14.00),
        "openai::gpt-5.2-codex": .init(inputPerMillion: 1.75, outputPerMillion: 14.00),
        "openai::gpt-5.1": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5.1-chat-latest": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5.1-codex": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5.1-codex-max": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5-chat-latest": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5-codex": .init(inputPerMillion: 1.25, outputPerMillion: 10.00),
        "openai::gpt-5-mini": .init(inputPerMillion: 0.25, outputPerMillion: 2.00),
        "openai::gpt-5-nano": .init(inputPerMillion: 0.05, outputPerMillion: 0.40),
        "openai::gpt-5.2-pro": .init(inputPerMillion: 21.00, outputPerMillion: 168.00),
        "openai::gpt-5-pro": .init(inputPerMillion: 15.00, outputPerMillion: 120.00),
        "openai::gpt-4.1": .init(inputPerMillion: 2.00, outputPerMillion: 8.00),
        "openai::gpt-4.1-mini": .init(inputPerMillion: 0.40, outputPerMillion: 1.60),
        "openai::gpt-4.1-nano": .init(inputPerMillion: 0.10, outputPerMillion: 0.40),
        "openai::gpt-4o": .init(inputPerMillion: 2.50, outputPerMillion: 10.00),
        "openai::gpt-4o-2024-05-13": .init(inputPerMillion: 5.00, outputPerMillion: 15.00),
        "openai::gpt-4o-mini": .init(inputPerMillion: 0.15, outputPerMillion: 0.60),

        // Anthropic Claude models, USD per 1M tokens (base input/output)
        "anthropic::claude-opus-4-1": .init(inputPerMillion: 15.00, outputPerMillion: 75.00),
        "anthropic::claude-opus-4": .init(inputPerMillion: 15.00, outputPerMillion: 75.00),
        "anthropic::claude-sonnet-4": .init(inputPerMillion: 3.00, outputPerMillion: 15.00),
        "anthropic::claude-3-7-sonnet": .init(inputPerMillion: 3.00, outputPerMillion: 15.00),
        "anthropic::claude-3-5-sonnet": .init(inputPerMillion: 3.00, outputPerMillion: 15.00),
        "anthropic::claude-3-5-haiku": .init(inputPerMillion: 0.80, outputPerMillion: 4.00),
        "anthropic::claude-3-haiku": .init(inputPerMillion: 0.25, outputPerMillion: 1.25),
        "anthropic::claude-3-opus": .init(inputPerMillion: 15.00, outputPerMillion: 75.00),

        // Groq public pricing table, USD per 1M tokens
        "groq::openai/gpt-oss-20b": .init(inputPerMillion: 0.075, outputPerMillion: 0.30),
        "groq::openai/gpt-oss-120b": .init(inputPerMillion: 0.15, outputPerMillion: 0.60),
        "groq::gpt-oss-20b": .init(inputPerMillion: 0.075, outputPerMillion: 0.30),
        "groq::gpt-oss-120b": .init(inputPerMillion: 0.15, outputPerMillion: 0.60)
    ]

    static func pricing(provider: ProviderKind, modelID: String) -> ModelPricing? {
        let key = PricingStore.key(provider: provider, model: modelID)
        if let value = exact[key] { return value }
        let normalized = modelID.lowercased()
        switch provider {
        case .anthropic:
            if normalized.contains("opus") { return .init(inputPerMillion: 15, outputPerMillion: 75) }
            if normalized.contains("sonnet") { return .init(inputPerMillion: 3, outputPerMillion: 15) }
            if normalized.contains("haiku") && normalized.contains("3-5") { return .init(inputPerMillion: 0.80, outputPerMillion: 4) }
            if normalized.contains("haiku") { return .init(inputPerMillion: 0.25, outputPerMillion: 1.25) }
        case .groq:
            if normalized.contains("gpt-oss-120b") { return .init(inputPerMillion: 0.15, outputPerMillion: 0.60) }
            if normalized.contains("gpt-oss-20b") { return .init(inputPerMillion: 0.075, outputPerMillion: 0.30) }
        case .openai:
            if normalized.contains("gpt-5.2") { return .init(inputPerMillion: 1.75, outputPerMillion: 14) }
            if normalized.contains("gpt-5-mini") { return .init(inputPerMillion: 0.25, outputPerMillion: 2) }
            if normalized.contains("gpt-5-nano") { return .init(inputPerMillion: 0.05, outputPerMillion: 0.40) }
            if normalized.contains("gpt-5") { return .init(inputPerMillion: 1.25, outputPerMillion: 10) }
            if normalized.contains("gpt-4.1-mini") { return .init(inputPerMillion: 0.40, outputPerMillion: 1.60) }
            if normalized.contains("gpt-4.1-nano") { return .init(inputPerMillion: 0.10, outputPerMillion: 0.40) }
            if normalized.contains("gpt-4.1") { return .init(inputPerMillion: 2, outputPerMillion: 8) }
            if normalized.contains("gpt-4o-mini") { return .init(inputPerMillion: 0.15, outputPerMillion: 0.60) }
            if normalized.contains("gpt-4o") { return .init(inputPerMillion: 2.50, outputPerMillion: 10) }
        case .openrouter:
            return nil
        }
        return nil
    }
}
