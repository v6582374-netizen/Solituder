import Foundation

public final class ElevenLabsSpeechOutputAdapter: SpeechOutputAdapter, @unchecked Sendable {
    private let apiKeyProvider: @Sendable () async throws -> String
    private let securityPolicy: SecurityPolicyEngine
    private let urlSession: URLSession
    private let endpointRoot: URL
    private let modelId: String
    private let networkAllowlist: NetworkDomainAllowlist

    public init(
        securityPolicy: SecurityPolicyEngine,
        apiKeyProvider: @escaping @Sendable () async throws -> String,
        urlSession: URLSession = .shared,
        endpointRoot: URL = URL(string: "https://api.elevenlabs.io")!,
        modelId: String = "eleven_turbo_v2_5",
        networkAllowlist: NetworkDomainAllowlist = .defaultModelHosts
    ) {
        self.securityPolicy = securityPolicy
        self.apiKeyProvider = apiKeyProvider
        self.urlSession = urlSession
        self.endpointRoot = endpointRoot
        self.modelId = modelId
        self.networkAllowlist = networkAllowlist
    }

    public func synthesize(text: String, voiceId: String) -> AudioBufferStream {
        AudioBufferStream { continuation in
            Task {
                do {
                    let rawApiKey = try await apiKeyProvider()
                    let apiKey = APIKeySanitizer.normalize(rawApiKey, provider: .elevenLabs)
                    guard securityPolicy.validateApiKeyFormat(provider: .elevenLabs, key: apiKey) else {
                        throw AgentError.invalidCredentialFormat(provider: .elevenLabs)
                    }

                    let audioData = try await fetchAudio(text: text, voiceId: voiceId, apiKey: apiKey)
                    continuation.yield(audioData)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func fetchAudio(text: String, voiceId: String, apiKey: String) async throws -> Data {
        let endpoint = endpointRoot
            .appendingPathComponent("v1")
            .appendingPathComponent("text-to-speech")
            .appendingPathComponent(voiceId)
            .appendingPathComponent("stream")
        try networkAllowlist.validate(url: endpoint)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let payload: [String: Any] = [
            "text": text,
            "model_id": modelId,
            "voice_settings": [
                "stability": 0.45,
                "similarity_boost": 0.85
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentError.other(message: "Invalid TTS response")
        }

        guard (200..<300).contains(http.statusCode) else {
            if let detail = parseFailureDetail(from: data) {
                throw AgentError.other(
                    message: "ElevenLabs request failed (\(http.statusCode)): \(detail)"
                )
            }
            throw AgentError.networkFailure(code: http.statusCode)
        }

        return data
    }

    private func parseFailureDetail(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let detail = json["detail"] as? String, detail.isEmpty == false {
            return detail
        }

        if
            let detailObject = json["detail"] as? [String: Any],
            let message = detailObject["message"] as? String
        {
            let status = detailObject["status"] as? String
            if let status, status.isEmpty == false, message.isEmpty == false {
                return "\(status): \(message)"
            }
            if message.isEmpty == false {
                return message
            }
            if let status, status.isEmpty == false {
                return status
            }
        }

        if let message = json["message"] as? String, message.isEmpty == false {
            return message
        }

        return nil
    }
}
