import Foundation

struct AnthropicClient {
    private let apiKey: String
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String = APIConfig.anthropicKey) {
        self.apiKey = apiKey
    }

    func send(
        system: String? = nil,
        messages: [[String: Any]],
        tools: [[String: Any]],
        toolName: String,
        maxTokens: Int = 1024
    ) async throws -> [String: Any] {
        var body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": maxTokens,
            "messages": messages,
            "tools": tools,
            "tool_choice": ["type": "tool", "name": toolName]
        ]
        if let system { body["system"] = system }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AnthropicError.http(code, body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AnthropicError.invalidResponse
        }
        return json
    }

    func toolInput(from response: [String: Any]) throws -> [String: Any] {
        guard
            let content = response["content"] as? [[String: Any]],
            let block = content.first(where: { $0["type"] as? String == "tool_use" }),
            let input = block["input"] as? [String: Any]
        else { throw AnthropicError.noToolUse }
        return input
    }

    func decode<T: Decodable>(_ type: T.Type, from response: [String: Any]) throws -> T {
        let input = try toolInput(from: response)
        let data = try JSONSerialization.data(withJSONObject: input)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum AnthropicError: LocalizedError {
    case http(Int, String)
    case invalidResponse
    case noToolUse

    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "API \(code): \(body.prefix(200))"
        case .invalidResponse: return "Invalid API response"
        case .noToolUse: return "API did not return structured output"
        }
    }
}
