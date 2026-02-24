import Foundation

public enum SolituderAgentFactory {
    public static func makeLiveAgent(
        wakeWordModels: [WakeWordModel] = WakeWordModel.presets,
        configuration: VoiceSessionConfiguration = VoiceSessionConfiguration(),
        credentialStore: CredentialStore = KeychainCredentialStore(),
        memoryStore: LocalMemoryStore = EncryptedLocalMemoryStore(),
        securityPolicy: SecurityPolicyEngine = DefaultSecurityPolicyEngine()
    ) -> VoiceSessionOrchestrator {
        let wakeWordEngine = KeywordWakeWordEngine(models: wakeWordModels)
        let llm = OpenAIProviderAdapter(securityPolicy: securityPolicy)
        let speech = ElevenLabsSpeechOutputAdapter(
            securityPolicy: securityPolicy,
            apiKeyProvider: {
                guard let key = try await credentialStore.getKey(for: .elevenLabs) else {
                    throw AgentError.missingCredential(provider: .elevenLabs)
                }
                return APIKeySanitizer.normalize(key, provider: .elevenLabs)
            }
        )

        return VoiceSessionOrchestrator(
            wakeWordEngine: wakeWordEngine,
            llmAdapter: llm,
            speechAdapter: speech,
            memoryStore: memoryStore,
            securityPolicy: securityPolicy,
            credentialStore: credentialStore,
            configuration: configuration
        )
    }
}
