import Foundation

public typealias AudioBufferStream = AsyncThrowingStream<Data, Error>

public enum AgentLifecycleState: Equatable, Sendable {
    case disarmed
    case armedForeground(modelId: String)
    case conversing(sessionID: UUID)
    case backgroundSuspended(previousModelId: String?)
}

public enum CredentialProvider: String, Codable, CaseIterable, Sendable {
    case openAI = "openai"
    case elevenLabs = "elevenlabs"
}

public struct WakeWordDetectionEvent: Equatable, Sendable {
    public let modelId: String
    public let phrase: String
    public let detectedAt: Date

    public init(modelId: String, phrase: String, detectedAt: Date = Date()) {
        self.modelId = modelId
        self.phrase = phrase
        self.detectedAt = detectedAt
    }
}

public struct RealtimeConnectionConfig: Equatable, Sendable {
    public let provider: CredentialProvider
    public let model: String
    public let apiKey: String
    public let sessionID: UUID
    public let metadata: [String: String]

    public init(
        provider: CredentialProvider,
        model: String,
        apiKey: String,
        sessionID: UUID,
        metadata: [String: String] = [:]
    ) {
        self.provider = provider
        self.model = model
        self.apiKey = apiKey
        self.sessionID = sessionID
        self.metadata = metadata
    }
}

public struct LLMResponse: Equatable, Sendable {
    public let text: String
    public let latencyMs: Int

    public init(text: String, latencyMs: Int) {
        self.text = text
        self.latencyMs = latencyMs
    }
}

public struct MemoryQueryContext: Equatable, Sendable {
    public let keywords: [String]
    public let limit: Int

    public init(keywords: [String], limit: Int = 10) {
        self.keywords = keywords
        self.limit = max(limit, 1)
    }
}

public struct MemoryRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let createdAt: Date
    public let summary: String
    public let tags: [String]

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        createdAt: Date = Date(),
        summary: String,
        tags: [String]
    ) {
        self.id = id
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.summary = summary
        self.tags = tags
    }
}

public struct RuntimeRiskReport: Equatable, Sendable {
    public let isDebuggerAttached: Bool
    public let isJailbrokenOrTampered: Bool
    public let reasons: [String]

    public var shouldDegradeCapabilities: Bool {
        isDebuggerAttached || isJailbrokenOrTampered
    }

    public init(
        isDebuggerAttached: Bool,
        isJailbrokenOrTampered: Bool,
        reasons: [String]
    ) {
        self.isDebuggerAttached = isDebuggerAttached
        self.isJailbrokenOrTampered = isJailbrokenOrTampered
        self.reasons = reasons
    }
}

public protocol WakeWordEngine: Sendable {
    func start(modelId: String) async throws
    func stop() async
    func onDetected(callback: @escaping @Sendable (WakeWordDetectionEvent) -> Void) async
    func processTranscript(_ transcript: String) async
}

public protocol VoiceSessionOrchestrating: Sendable {
    func arm(modelId: String) async throws
    func disarm() async
    func beginConversation() async throws -> UUID
    func endConversation(summary: String?, tags: [String]) async throws
    func transitionToBackground() async
    func transitionToForeground() async throws
    func sendText(_ text: String) async throws -> LLMResponse
    func synthesize(text: String) async -> AudioBufferStream
    func ingestTranscript(_ transcript: String) async
    func currentState() async -> AgentLifecycleState
}

public protocol LLMProviderAdapter: Sendable {
    func connectRealtime(config: RealtimeConnectionConfig) async throws
    func sendText(input: String) async throws -> LLMResponse
    func close() async
}

public protocol SpeechOutputAdapter: Sendable {
    func synthesize(text: String, voiceId: String) -> AudioBufferStream
}

public protocol LocalMemoryStore: Sendable {
    func saveSummary(sessionId: UUID, summary: String, tags: [String]) async throws
    func query(context: MemoryQueryContext) async throws -> [MemoryRecord]
    func deleteAll() async throws
}

public protocol SecurityPolicyEngine: Sendable {
    func validateApiKeyFormat(provider: CredentialProvider, key: String) -> Bool
    func redactLogs(payload: String) -> String
    func runtimeRiskCheck() -> RuntimeRiskReport
}

public protocol CredentialStore: Sendable {
    func setKey(_ key: String, for provider: CredentialProvider) async throws
    func getKey(for provider: CredentialProvider) async throws -> String?
    func removeKey(for provider: CredentialProvider) async throws
}
