import Foundation

final class OpenAICompatibleProvider: LLMProviderClient {
    private let baseURL: URL
    private let extraHeaders: [String: String]

    init(baseURL: URL, extraHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.extraHeaders = extraHeaders
    }

    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse {
        let urlRequest = try makeChatRequest(request, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response: response, data: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = extractText(from: object) else { throw LLMError.invalidResponse }
        return LLMResponse(text: text, usage: parseUsage(object?["usage"] as? [String: Any]))
    }

    func listModels(apiKey: String) async throws -> [ProviderModel] {
        let request = makeListModelsRequest(apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = object?["data"] as? [[String: Any]] ?? []
        return items.compactMap(decodeModel)
            .filter { keepModelKind($0) }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    private func makeChatRequest(_ request: LLMRequest, apiKey: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in extraHeaders { urlRequest.setValue(value, forHTTPHeaderField: key) }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": request.model,
            "messages": [
                ["role": "system", "content": request.system],
                ["role": "user", "content": request.user]
            ],
            "temperature": request.temperature,
            "max_tokens": request.maxTokens
        ])
        return urlRequest
    }

    private func makeListModelsRequest(apiKey: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (key, value) in extraHeaders { request.setValue(value, forHTTPHeaderField: key) }
        return request
    }

    private func extractText(from object: [String: Any]?) -> String? {
        let choices = object?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String
    }

    private func decodeModel(_ item: [String: Any]) -> ProviderModel? {
        guard let id = item["id"] as? String else { return nil }
        let name = item["name"] as? String ?? id
        let description = item["description"] as? String
        let context = item["context_length"] as? Int ?? item["contextLength"] as? Int
        let pricing = parseModelPricing(item["pricing"] as? [String: Any])
        return ProviderModel(id: id, name: name, description: description, contextLength: context, pricing: pricing)
    }

    private func keepModelKind(_ model: ProviderModel) -> Bool {
        let id = model.id.lowercased()
        return !id.contains("embedding") && !id.contains("whisper") && !id.contains("tts") && !id.contains("image") && !id.contains("moderation")
    }

    private func parseModelPricing(_ pricing: [String: Any]?) -> ModelPricing? {
        guard let pricing else { return nil }
        func doubleValue(_ key: String) -> Double? {
            if let value = pricing[key] as? Double { return value }
            if let value = pricing[key] as? Int { return Double(value) }
            if let value = pricing[key] as? String { return Double(value) }
            return nil
        }
        guard let prompt = doubleValue("prompt") ?? doubleValue("input"),
              let completion = doubleValue("completion") ?? doubleValue("output") else { return nil }
        // OpenRouter exposes prices per token; Retypo stores USD per 1M tokens.
        return ModelPricing(inputPerMillion: prompt * 1_000_000, outputPerMillion: completion * 1_000_000)
    }

    private func parseUsage(_ usage: [String: Any]?) -> TokenUsage {
        guard let usage else { return .zero }
        let input = usage["prompt_tokens"] as? Int
            ?? usage["input_tokens"] as? Int
            ?? 0
        let output = usage["completion_tokens"] as? Int
            ?? usage["output_tokens"] as? Int
            ?? 0
        return TokenUsage(inputTokens: input, outputTokens: output)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.badStatus(http.statusCode, body)
        }
    }
}
