import Foundation

public actor OpenAIProviderAdapter: LLMProviderAdapter {
    private let securityPolicy: SecurityPolicyEngine
    private let urlSession: URLSession
    private let realtimeEndpoint: URL
    private let fallbackEndpoint: URL
    private let fallbackModel: String
    private let networkAllowlist: NetworkDomainAllowlist
    private var websocketTask: URLSessionWebSocketTask?
    private var activeConfig: RealtimeConnectionConfig?

    public init(
        securityPolicy: SecurityPolicyEngine,
        urlSession: URLSession = .shared,
        realtimeEndpoint: URL = URL(string: "wss://api.openai.com/v1/realtime")!,
        fallbackEndpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
        fallbackModel: String = "gpt-4.1-mini",
        networkAllowlist: NetworkDomainAllowlist = .defaultModelHosts
    ) {
        self.securityPolicy = securityPolicy
        self.urlSession = urlSession
        self.realtimeEndpoint = realtimeEndpoint
        self.fallbackEndpoint = fallbackEndpoint
        self.fallbackModel = fallbackModel
        self.networkAllowlist = networkAllowlist
    }

    public func connectRealtime(config: RealtimeConnectionConfig) async throws {
        guard config.provider == .openAI else {
            throw AgentError.other(message: "OpenAI adapter only supports openAI provider")
        }
        let normalizedApiKey = APIKeySanitizer.normalize(config.apiKey, provider: .openAI)

        guard securityPolicy.validateApiKeyFormat(provider: .openAI, key: normalizedApiKey) else {
            throw AgentError.invalidCredentialFormat(provider: .openAI)
        }

        // Stable MVP path: keep session config only and use HTTP responses for turns.
        websocketTask?.cancel(with: .goingAway, reason: nil)
        websocketTask = nil
        activeConfig = RealtimeConnectionConfig(
            provider: config.provider,
            model: config.model,
            apiKey: normalizedApiKey,
            sessionID: config.sessionID,
            metadata: config.metadata
        )
    }

    public func sendText(input: String) async throws -> LLMResponse {
        guard let config = activeConfig else {
            throw AgentError.providerNotConnected
        }

        let start = Date()
        return try await sendViaFallbackHTTP(input: input, config: config, startedAt: start)
    }

    public func close() async {
        websocketTask?.cancel(with: .goingAway, reason: nil)
        websocketTask = nil
        activeConfig = nil
    }

    private func sendViaRealtime(input: String, startedAt: Date) async throws -> LLMResponse {
        guard let websocketTask else {
            throw AgentError.providerNotConnected
        }

        let payload: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["text"],
                "instructions": input
            ]
        ]

        let requestData = try JSONSerialization.data(withJSONObject: payload)
        guard let requestText = String(data: requestData, encoding: .utf8) else {
            throw AgentError.other(message: "Unable to encode realtime payload")
        }

        try await websocketTask.send(.string(requestText))

        let incoming = try await websocketTask.receive()
        switch incoming {
        case .string(let value):
            let text = parseRealtimeText(from: value)
            let latency = Int(Date().timeIntervalSince(startedAt) * 1000)
            return LLMResponse(text: text, latencyMs: latency)
        case .data(let data):
            let text = parseRealtimeText(from: String(decoding: data, as: UTF8.self))
            let latency = Int(Date().timeIntervalSince(startedAt) * 1000)
            return LLMResponse(text: text, latencyMs: latency)
        @unknown default:
            throw AgentError.unsupportedResponse
        }
    }

    private func sendViaFallbackHTTP(
        input: String,
        config: RealtimeConnectionConfig,
        startedAt: Date
    ) async throws -> LLMResponse {
        var request = URLRequest(url: fallbackEndpoint)
        try networkAllowlist.validate(url: fallbackEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": fallbackModel,
            "input": input
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentError.other(message: "Non HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            throw AgentError.networkFailure(code: http.statusCode)
        }

        let text = try parseFallbackText(data: data)
        let latency = Int(Date().timeIntervalSince(startedAt) * 1000)
        return LLMResponse(text: text, latencyMs: latency)
    }

    private func parseRealtimeText(from raw: String) -> String {
        guard let data = raw.data(using: .utf8) else {
            return raw
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["type"] as? String
        else {
            return raw
        }

        if type.contains("output_text"), let delta = json["delta"] as? String {
            return delta
        }

        if
            let response = json["response"] as? [String: Any],
            let outputText = response["output_text"] as? String
        {
            return outputText
        }

        return raw
    }

    private func parseFallbackText(data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AgentError.unsupportedResponse
        }

        if let direct = json["output_text"] as? String, direct.isEmpty == false {
            return direct
        }

        if
            let output = json["output"] as? [[String: Any]],
            let first = output.first,
            let content = first["content"] as? [[String: Any]],
            let textNode = content.first,
            let text = textNode["text"] as? String,
            text.isEmpty == false
        {
            return text
        }

        throw AgentError.unsupportedResponse
    }
}
