import Foundation

final class AnthropicProvider: LLMProviderClient {
    let kind: ProviderKind = .anthropic
    private let baseURL = URL(string: "https://api.anthropic.com/v1")!

    func complete(_ request: LLMRequest, apiKey: String) async throws -> LLMResponse {
        let url = baseURL.appendingPathComponent("messages")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": request.model,
            "system": request.system,
            "messages": [["role": "user", "content": request.user]],
            "max_tokens": request.maxTokens,
            "temperature": request.temperature
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response: response, data: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let blocks = object?["content"] as? [[String: Any]]
        let text = blocks?.compactMap { $0["text"] as? String }.joined(separator: "")
        if let text, !text.isEmpty { return LLMResponse(text: text) }
        throw LLMError.invalidResponse
    }

    func listModels(apiKey: String) async throws -> [ProviderModel] {
        let url = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataArray = object?["data"] as? [[String: Any]] ?? []
        return dataArray.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            let name = item["display_name"] as? String ?? item["name"] as? String ?? id
            return ProviderModel(id: id, name: name)
        }
        .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.badStatus(http.statusCode, body)
        }
    }
}
