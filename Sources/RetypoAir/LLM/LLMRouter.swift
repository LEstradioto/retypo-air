import Foundation

final class LLMRouter {
    private let providers: [ProviderKind: LLMProviderClient]

    init() {
        providers = [
            .groq: OpenAICompatibleProvider(baseURL: URL(staticString: "https://api.groq.com/openai/v1")),
            .openrouter: OpenAICompatibleProvider(
                baseURL: URL(staticString: "https://openrouter.ai/api/v1"),
                extraHeaders: [
                    "HTTP-Referer": "https://retypo-air.local",
                    "X-Title": "Retypo Air"
                ]
            ),
            .anthropic: AnthropicProvider(),
            .openai: OpenAIResponsesProvider()
        ]
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        guard let apiKey = APIKeyStore.apiKey(for: request.provider) else { throw LLMError.missingAPIKey(request.provider) }
        guard let client = providers[request.provider] else { throw LLMError.invalidResponse }
        return try await client.complete(request, apiKey: apiKey)
    }

    func listModels(for provider: ProviderKind) async throws -> [ProviderModel] {
        guard let apiKey = APIKeyStore.apiKey(for: provider) else { throw LLMError.missingAPIKey(provider) }
        guard let client = providers[provider] else { throw LLMError.invalidResponse }
        return try await client.listModels(apiKey: apiKey)
    }
}
