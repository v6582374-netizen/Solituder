import Foundation
@testable import SolituderKit

actor MockWakeWordEngine: WakeWordEngine {
    private var callback: (@Sendable (WakeWordDetectionEvent) -> Void)?
    private(set) var startedModelId: String?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(modelId: String) async throws {
        startedModelId = modelId
        startCount += 1
    }

    func stop() async {
        stopCount += 1
    }

    func onDetected(callback: @escaping @Sendable (WakeWordDetectionEvent) -> Void) async {
        self.callback = callback
    }

    func processTranscript(_ transcript: String) async {
        guard let startedModelId else {
            return
        }

        let normalized = transcript.lowercased()
        if normalized.contains("jarvis")
            || normalized.contains("javis")
            || normalized.contains("solituder")
            || transcript.contains("贾维斯")
            || transcript.contains("杰维斯")
            || transcript.contains("孤旅")
        {
            callback?(WakeWordDetectionEvent(modelId: startedModelId, phrase: transcript))
        }
    }

    func emit(phrase: String, modelId: String) {
        callback?(WakeWordDetectionEvent(modelId: modelId, phrase: phrase))
    }
}

actor MockLLMProviderAdapter: LLMProviderAdapter {
    private(set) var connectCount = 0
    private(set) var closeCount = 0
    private(set) var lastInput: String?
    private var failNextSendWithProviderNotConnected = false

    func connectRealtime(config: RealtimeConnectionConfig) async throws {
        connectCount += 1
    }

    func sendText(input: String) async throws -> LLMResponse {
        if failNextSendWithProviderNotConnected {
            failNextSendWithProviderNotConnected = false
            throw AgentError.providerNotConnected
        }
        lastInput = input
        return LLMResponse(text: "echo:\(input)", latencyMs: 100)
    }

    func close() async {
        closeCount += 1
    }

    func failNextSend() {
        failNextSendWithProviderNotConnected = true
    }
}

struct MockSpeechOutputAdapter: SpeechOutputAdapter {
    func synthesize(text: String, voiceId: String) -> AudioBufferStream {
        AudioBufferStream { continuation in
            continuation.yield(Data("\(voiceId):\(text)".utf8))
            continuation.finish()
        }
    }
}

actor MockMemoryStore: LocalMemoryStore {
    private(set) var records: [MemoryRecord] = []

    func saveSummary(sessionId: UUID, summary: String, tags: [String]) async throws {
        records.append(MemoryRecord(sessionID: sessionId, summary: summary, tags: tags))
    }

    func query(context: MemoryQueryContext) async throws -> [MemoryRecord] {
        records
    }

    func deleteAll() async throws {
        records = []
    }
}
