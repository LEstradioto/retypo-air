import Foundation

final class AnthropicProvider: LLMProviderClient {
    private let baseURL = URL(staticString: "https://api.anthropic.com/v1")

    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse {
        let urlRequest = try makeMessagesRequest(request, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response: response, data: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = extractText(from: object), !text.isEmpty else {
            throw LLMError.invalidResponse
        }
        return LLMResponse(text: text, usage: parseUsage(object?["usage"] as? [String: Any]))
    }

    func listModels(apiKey: String) async throws -> [ProviderModel] {
        let request = makeListModelsRequest(apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataArray = object?["data"] as? [[String: Any]] ?? []
        return dataArray.compactMap(decodeModel)
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    private func makeMessagesRequest(_ request: LLMRequest, apiKey: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("messages"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": request.model,
            "system": request.system,
            "messages": [["role": "user", "content": request.user]],
            "max_tokens": request.maxTokens,
            "temperature": request.temperature
        ])
        return urlRequest
    }

    private func makeListModelsRequest(apiKey: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        return request
    }

    private func extractText(from object: [String: Any]?) -> String? {
        let blocks = object?["content"] as? [[String: Any]]
        return blocks?.compactMap { $0["text"] as? String }.joined(separator: "")
    }

    private func decodeModel(_ item: [String: Any]) -> ProviderModel? {
        guard let id = item["id"] as? String else { return nil }
        let name = item["display_name"] as? String ?? item["name"] as? String ?? id
        return ProviderModel(id: id, name: name)
    }

    private func parseUsage(_ usage: [String: Any]?) -> TokenUsage {
        guard let usage else { return .zero }
        return TokenUsage(
            inputTokens: usage["input_tokens"] as? Int ?? 0,
            outputTokens: usage["output_tokens"] as? Int ?? 0
        )
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.badStatus(http.statusCode, body)
        }
    }
}
