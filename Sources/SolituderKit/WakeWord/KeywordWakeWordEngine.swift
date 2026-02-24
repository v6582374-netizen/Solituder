import Foundation

public actor KeywordWakeWordEngine: WakeWordEngine {
    private let models: [String: WakeWordModel]
    private var activeModel: WakeWordModel?
    private var callback: (@Sendable (WakeWordDetectionEvent) -> Void)?
    private var isRunning = false

    public init(models: [WakeWordModel] = WakeWordModel.presets) {
        self.models = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
    }

    public func start(modelId: String) async throws {
        guard let model = models[modelId] else {
            throw AgentError.modelNotFound(modelId: modelId)
        }
        activeModel = model
        isRunning = true
    }

    public func stop() async {
        isRunning = false
    }

    public func onDetected(callback: @escaping @Sendable (WakeWordDetectionEvent) -> Void) async {
        self.callback = callback
    }

    public func processTranscript(_ transcript: String) async {
        guard isRunning, let model = activeModel else {
            return
        }

        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let phrase = model.triggerPhrases.first(where: { normalized.contains($0.lowercased()) }) else {
            return
        }

        callback?(WakeWordDetectionEvent(modelId: model.id, phrase: phrase))
    }
}
