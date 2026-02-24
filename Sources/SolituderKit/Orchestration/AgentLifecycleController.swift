import Foundation

public enum AgentScenePhase: Sendable {
    case active
    case inactive
    case background
}

public actor AgentLifecycleController {
    private let orchestrator: VoiceSessionOrchestrator
    private var backgroundStopTask: Task<Void, Never>?

    public init(orchestrator: VoiceSessionOrchestrator) {
        self.orchestrator = orchestrator
    }

    public func handleScenePhaseChange(_ phase: AgentScenePhase) async {
        switch phase {
        case .active:
            backgroundStopTask?.cancel()
            backgroundStopTask = nil
            try? await orchestrator.transitionToForeground()
        case .inactive:
            break
        case .background:
            backgroundStopTask?.cancel()
            backgroundStopTask = Task {
                try? await Task.sleep(for: .seconds(2))
                await orchestrator.transitionToBackground()
            }
        }
    }
}
