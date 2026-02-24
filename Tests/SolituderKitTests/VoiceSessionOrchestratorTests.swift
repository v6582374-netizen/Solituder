#if canImport(Testing)
import Testing
@testable import SolituderKit

@Suite("VoiceSessionOrchestrator")
struct VoiceSessionOrchestratorTests {
    @Test
    func armMovesToArmedState() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials
        )

        try await orchestrator.arm(modelId: "jarvis-cn")

        #expect(await orchestrator.currentState() == .armedForeground(modelId: "jarvis-cn"))
        #expect(await wake.startCount == 1)
    }

    @Test
    func wakeWordAutoBeginsConversation() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials,
            configuration: VoiceSessionConfiguration(autoBeginConversationOnWakeWord: true)
        )

        try await orchestrator.arm(modelId: "jarvis-cn")
        await wake.emit(phrase: "你好贾维斯", modelId: "jarvis-cn")

        try await Task.sleep(for: .milliseconds(120))
        #expect(await llm.connectCount == 1)
    }

    @Test
    func transitionToBackgroundStopsWakeWord() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials
        )

        try await orchestrator.arm(modelId: "jarvis-cn")
        await orchestrator.transitionToBackground()

        #expect(await wake.stopCount == 1)
        #expect(await orchestrator.currentState() == .backgroundSuspended(previousModelId: "jarvis-cn"))
    }

    @Test
    func endConversationPersistsSummary() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials
        )

        try await orchestrator.arm(modelId: "jarvis-cn")
        _ = try await orchestrator.beginConversation()
        try await orchestrator.endConversation(summary: "Discussed todo priorities", tags: ["todo", "planning"])

        let saved = try await memory.query(context: MemoryQueryContext(keywords: []))
        #expect(saved.count == 1)
        #expect(saved.first?.summary == "Discussed todo priorities")
        #expect(await orchestrator.currentState() == .armedForeground(modelId: "jarvis-cn"))
    }

    @Test
    func ingestTranscriptCanTriggerWakeWordConversation() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials,
            configuration: VoiceSessionConfiguration(autoBeginConversationOnWakeWord: true)
        )

        try await orchestrator.arm(modelId: "jarvis-en")
        await orchestrator.ingestTranscript("hey javis help me prioritize")

        try await Task.sleep(for: .milliseconds(120))
        #expect(await llm.connectCount == 1)
    }

    @Test
    func sendTextReconnectsWhenProviderDropped() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials
        )

        try await orchestrator.arm(modelId: "jarvis-en")
        _ = try await orchestrator.beginConversation()
        await llm.failNextSend()

        let response = try await orchestrator.sendText("hello")

        #expect(response.text == "echo:hello")
        #expect(await llm.connectCount == 2)
    }
}
#elseif canImport(XCTest)
import XCTest
@testable import SolituderKit

final class VoiceSessionOrchestratorTests: XCTestCase {
    func testArmMovesToArmedState() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials
        )

        try await orchestrator.arm(modelId: "jarvis-cn")

        XCTAssertEqual(await orchestrator.currentState(), .armedForeground(modelId: "jarvis-cn"))
        XCTAssertEqual(await wake.startCount, 1)
    }

    func testWakeWordAutoBeginsConversation() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials,
            configuration: VoiceSessionConfiguration(autoBeginConversationOnWakeWord: true)
        )

        try await orchestrator.arm(modelId: "jarvis-cn")
        await wake.emit(phrase: "你好贾维斯", modelId: "jarvis-cn")

        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(await llm.connectCount, 1)
    }

    func testTransitionToBackgroundStopsWakeWord() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials
        )

        try await orchestrator.arm(modelId: "jarvis-cn")
        await orchestrator.transitionToBackground()

        XCTAssertEqual(await wake.stopCount, 1)
        XCTAssertEqual(await orchestrator.currentState(), .backgroundSuspended(previousModelId: "jarvis-cn"))
    }

    func testEndConversationPersistsSummary() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials
        )

        try await orchestrator.arm(modelId: "jarvis-cn")
        _ = try await orchestrator.beginConversation()
        try await orchestrator.endConversation(summary: "Discussed todo priorities", tags: ["todo", "planning"])

        let saved = try await memory.query(context: MemoryQueryContext(keywords: []))
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.summary, "Discussed todo priorities")
        XCTAssertEqual(await orchestrator.currentState(), .armedForeground(modelId: "jarvis-cn"))
    }

    func testIngestTranscriptCanTriggerWakeWordConversation() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials,
            configuration: VoiceSessionConfiguration(autoBeginConversationOnWakeWord: true)
        )

        try await orchestrator.arm(modelId: "jarvis-en")
        await orchestrator.ingestTranscript("hey javis help me prioritize")

        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(await llm.connectCount, 1)
    }

    func testSendTextReconnectsWhenProviderDropped() async throws {
        let wake = MockWakeWordEngine()
        let llm = MockLLMProviderAdapter()
        let memory = MockMemoryStore()
        let credentials = InMemoryCredentialStore()
        try await credentials.setKey("sk-test-key-1234567890", for: .openAI)

        let orchestrator = VoiceSessionOrchestrator(
            wakeWordEngine: wake,
            llmAdapter: llm,
            speechAdapter: MockSpeechOutputAdapter(),
            memoryStore: memory,
            securityPolicy: DefaultSecurityPolicyEngine(),
            credentialStore: credentials
        )

        try await orchestrator.arm(modelId: "jarvis-en")
        _ = try await orchestrator.beginConversation()
        await llm.failNextSend()

        let response = try await orchestrator.sendText("hello")

        XCTAssertEqual(response.text, "echo:hello")
        XCTAssertEqual(await llm.connectCount, 2)
    }
}
#endif
