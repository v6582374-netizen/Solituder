import Foundation

public struct VoiceSessionConfiguration: Equatable, Sendable {
    public let llmProvider: CredentialProvider
    public let realtimeModel: String
    public let voiceId: String
    public let autoBeginConversationOnWakeWord: Bool

    public init(
        llmProvider: CredentialProvider = .openAI,
        realtimeModel: String = "gpt-4o-realtime-preview",
        voiceId: String = "EXAVITQu4vr4xnSDxMaL",
        autoBeginConversationOnWakeWord: Bool = true
    ) {
        self.llmProvider = llmProvider
        self.realtimeModel = realtimeModel
        self.voiceId = voiceId
        self.autoBeginConversationOnWakeWord = autoBeginConversationOnWakeWord
    }
}

public actor VoiceSessionOrchestrator: VoiceSessionOrchestrating {
    private let wakeWordEngine: WakeWordEngine
    private let llmAdapter: LLMProviderAdapter
    private let speechAdapter: SpeechOutputAdapter
    private let memoryStore: LocalMemoryStore
    private let securityPolicy: SecurityPolicyEngine
    private let credentialStore: CredentialStore
    private let configuration: VoiceSessionConfiguration

    private var state: AgentLifecycleState = .disarmed
    private var armedModelId: String?
    private var activeSessionID: UUID?

    public init(
        wakeWordEngine: WakeWordEngine,
        llmAdapter: LLMProviderAdapter,
        speechAdapter: SpeechOutputAdapter,
        memoryStore: LocalMemoryStore,
        securityPolicy: SecurityPolicyEngine,
        credentialStore: CredentialStore,
        configuration: VoiceSessionConfiguration = VoiceSessionConfiguration()
    ) {
        self.wakeWordEngine = wakeWordEngine
        self.llmAdapter = llmAdapter
        self.speechAdapter = speechAdapter
        self.memoryStore = memoryStore
        self.securityPolicy = securityPolicy
        self.credentialStore = credentialStore
        self.configuration = configuration
    }

    public func arm(modelId: String) async throws {
        switch state {
        case .disarmed, .backgroundSuspended:
            break
        default:
            throw AgentError.invalidStateTransition(from: state, action: "arm")
        }

        let risk = securityPolicy.runtimeRiskCheck()
        if risk.shouldDegradeCapabilities {
            throw AgentError.runtimeRiskDetected(reasons: risk.reasons)
        }

        await wakeWordEngine.onDetected { [weak self] event in
            guard let self else {
                return
            }
            Task {
                await self.handleWakeWord(event)
            }
        }

        try await wakeWordEngine.start(modelId: modelId)
        armedModelId = modelId
        state = .armedForeground(modelId: modelId)
    }

    public func disarm() async {
        await wakeWordEngine.stop()
        await llmAdapter.close()

        armedModelId = nil
        activeSessionID = nil
        state = .disarmed
    }

    public func beginConversation() async throws -> UUID {
        guard case .armedForeground = state else {
            throw AgentError.invalidStateTransition(from: state, action: "beginConversation")
        }

        guard let apiKey = try await credentialStore.getKey(for: configuration.llmProvider) else {
            throw AgentError.missingCredential(provider: configuration.llmProvider)
        }
        let normalizedApiKey = APIKeySanitizer.normalize(apiKey, provider: configuration.llmProvider)

        guard securityPolicy.validateApiKeyFormat(provider: configuration.llmProvider, key: normalizedApiKey) else {
            throw AgentError.invalidCredentialFormat(provider: configuration.llmProvider)
        }

        let sessionID = UUID()
        let config = RealtimeConnectionConfig(
            provider: configuration.llmProvider,
            model: configuration.realtimeModel,
            apiKey: normalizedApiKey,
            sessionID: sessionID,
            metadata: [
                "locale": Locale.current.identifier,
                "client": "SolituderKit"
            ]
        )

        try await llmAdapter.connectRealtime(config: config)
        activeSessionID = sessionID
        state = .conversing(sessionID: sessionID)
        return sessionID
    }

    public func endConversation(summary: String? = nil, tags: [String] = []) async throws {
        guard case .conversing(let sessionID) = state else {
            throw AgentError.invalidStateTransition(from: state, action: "endConversation")
        }

        await llmAdapter.close()

        if let summary, summary.isEmpty == false {
            try await memoryStore.saveSummary(sessionId: sessionID, summary: summary, tags: tags)
        }

        activeSessionID = nil

        if let armedModelId {
            state = .armedForeground(modelId: armedModelId)
        } else {
            state = .disarmed
        }
    }

    public func transitionToBackground() async {
        switch state {
        case .armedForeground(let modelId):
            await wakeWordEngine.stop()
            state = .backgroundSuspended(previousModelId: modelId)
        case .conversing:
            await llmAdapter.close()
            state = .backgroundSuspended(previousModelId: armedModelId)
        case .disarmed:
            state = .backgroundSuspended(previousModelId: nil)
        case .backgroundSuspended:
            break
        }
    }

    public func transitionToForeground() async throws {
        guard case .backgroundSuspended(let modelId) = state else {
            return
        }

        guard let modelId else {
            state = .disarmed
            return
        }

        try await arm(modelId: modelId)
    }

    public func sendText(_ text: String) async throws -> LLMResponse {
        guard case .conversing = state else {
            throw AgentError.invalidStateTransition(from: state, action: "sendText")
        }

        do {
            return try await llmAdapter.sendText(input: text)
        } catch AgentError.providerNotConnected {
            try await reconnectProviderForActiveSession()
            return try await llmAdapter.sendText(input: text)
        }
    }

    public func synthesize(text: String) async -> AudioBufferStream {
        speechAdapter.synthesize(text: text, voiceId: configuration.voiceId)
    }

    public func ingestTranscript(_ transcript: String) async {
        await wakeWordEngine.processTranscript(transcript)
    }

    public func currentState() async -> AgentLifecycleState {
        state
    }

    private func handleWakeWord(_ event: WakeWordDetectionEvent) async {
        guard configuration.autoBeginConversationOnWakeWord else {
            return
        }

        guard case .armedForeground(let modelId) = state, modelId == event.modelId else {
            return
        }

        do {
            _ = try await beginConversation()
        } catch {
            // The app can surface this error via metrics/observability hooks.
        }
    }

    private func reconnectProviderForActiveSession() async throws {
        guard let sessionID = activeSessionID else {
            throw AgentError.providerNotConnected
        }

        guard let apiKey = try await credentialStore.getKey(for: configuration.llmProvider) else {
            throw AgentError.missingCredential(provider: configuration.llmProvider)
        }
        let normalizedApiKey = APIKeySanitizer.normalize(apiKey, provider: configuration.llmProvider)

        guard securityPolicy.validateApiKeyFormat(provider: configuration.llmProvider, key: normalizedApiKey) else {
            throw AgentError.invalidCredentialFormat(provider: configuration.llmProvider)
        }

        let config = RealtimeConnectionConfig(
            provider: configuration.llmProvider,
            model: configuration.realtimeModel,
            apiKey: normalizedApiKey,
            sessionID: sessionID,
            metadata: [
                "locale": Locale.current.identifier,
                "client": "SolituderKit"
            ]
        )
        try await llmAdapter.connectRealtime(config: config)
    }
}
