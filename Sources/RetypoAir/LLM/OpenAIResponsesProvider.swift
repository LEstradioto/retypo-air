import Foundation

final class OpenAIResponsesProvider: LLMProviderClient {
    let kind: ProviderKind = .openai
    private let baseURL = URL(staticString: "https://api.openai.com/v1")
    private let modelProvider = OpenAICompatibleProvider(kind: .openai, baseURL: URL(staticString: "https://api.openai.com/v1"))

    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse {
        let urlRequest = try makeResponsesRequest(request, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response: response, data: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = extractText(from: object), !text.isEmpty else {
            throw LLMError.invalidResponse
        }
        return LLMResponse(text: text, usage: parseUsage(object?["usage"] as? [String: Any]))
    }

    func listModels(apiKey: String) async throws -> [ProviderModel] {
        try await modelProvider.listModels(apiKey: apiKey)
    }

    private func makeResponsesRequest(_ request: LLMRequest, apiKey: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("responses"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": request.model,
            "instructions": request.system,
            "input": request.user,
            "max_output_tokens": request.maxTokens,
            "temperature": request.temperature
        ])
        return urlRequest
    }

    private func extractText(from object: [String: Any]?) -> String? {
        if let direct = object?["output_text"] as? String, !direct.isEmpty { return direct }
        guard let output = object?["output"] as? [[String: Any]] else { return nil }
        let text = output.flatMap { item -> [String] in
            let content = item["content"] as? [[String: Any]] ?? []
            return content.compactMap { $0["text"] as? String }
        }.joined(separator: "")
        return text.isEmpty ? nil : text
    }

    private func parseUsage(_ usage: [String: Any]?) -> TokenUsage {
        guard let usage else { return .zero }
        let input = usage["input_tokens"] as? Int ?? usage["prompt_tokens"] as? Int ?? 0
        let output = usage["output_tokens"] as? Int ?? usage["completion_tokens"] as? Int ?? 0
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
