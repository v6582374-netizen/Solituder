import AVFoundation
import Foundation
import SolituderKit
import Speech
import SwiftUI
import UIKit

@MainActor
final class AgentAppViewModel: ObservableObject {
    @Published var permissionStates: [PermissionKind: PermissionState] = Dictionary(
        uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .notDetermined) }
    )
    @Published var openAIKeyInput = ""
    @Published var elevenLabsKeyInput = ""
    @Published var selectedWakeModel = "jarvis-en"
    @Published var liveTranscript = ""
    @Published var lastUserUtterance = ""
    @Published var assistantReply = ""
    @Published var statusText = "Ready"
    @Published var errorMessage: String?
    @Published var hasStoredOpenAIKey = false
    @Published var hasStoredElevenLabsKey = false
    @Published var preferOnDeviceSpeech = true
    @Published var isArmed = false
    @Published var isConversing = false
    @Published var isRequestingPermissions = false
    @Published var lifecycleStateText = "disarmed"
    @Published var isKeyManagementPresented = false

    let wakeModelChoices: [(id: String, title: String)] = [
        ("jarvis-cn", "Jarvis (中文)"),
        ("jarvis-en", "Jarvis (English)"),
        ("solituder-cn", "Solituder (中文)"),
        ("solituder-en", "Solituder (English)")
    ]

    var allPermissionsGranted: Bool {
        PermissionKind.allCases.allSatisfy { state(for: $0) == .granted }
    }

    var voicePermissionsGranted: Bool {
        state(for: .microphone) == .granted
            && state(for: .speechRecognition) == .granted
    }

    var hasRequiredKeys: Bool {
        hasStoredOpenAIKey
    }

    private let permissionManager: PermissionManaging
    private let credentialStore: CredentialStore
    private let securityPolicy: SecurityPolicyEngine
    private let biometricAuthenticator: BiometricAuthenticating
    private let playbackService: SpeechPlaybackService
    private let speechListener: ForegroundSpeechListening
    private let orchestrator: VoiceSessionOrchestrating
    private let lifecycleController: AgentLifecycleController
    private var transcriptDebounceTask: Task<Void, Never>?
    private var isHandlingVoiceTurn = false
    private var isAssistantSpeaking = false
    private var lastSubmittedUtterance = ""
    private var lastAssistantReplyForEchoFilter = ""
    private var suppressTranscriptUntil = Date.distantPast
    private var speechRecoveryTask: Task<Void, Never>?
    private var speechRecoveryAttempt = 0

    init(
        permissionManager: PermissionManaging = SystemPermissionManager(),
        credentialStore: CredentialStore = KeychainCredentialStore(),
        securityPolicy: SecurityPolicyEngine = DefaultSecurityPolicyEngine(),
        biometricAuthenticator: BiometricAuthenticating = LocalBiometricAuthenticator(),
        playbackService: SpeechPlaybackService = SpeechPlaybackService(),
        speechListener: ForegroundSpeechListening = ForegroundSpeechListener()
    ) {
        self.permissionManager = permissionManager
        self.credentialStore = credentialStore
        self.securityPolicy = securityPolicy
        self.biometricAuthenticator = biometricAuthenticator
        self.playbackService = playbackService
        self.speechListener = speechListener

        let liveOrchestrator = SolituderAgentFactory.makeLiveAgent(
            credentialStore: credentialStore,
            securityPolicy: securityPolicy
        )
        self.orchestrator = liveOrchestrator
        self.lifecycleController = AgentLifecycleController(orchestrator: liveOrchestrator)
    }

    func bootstrap() async {
        await refreshPermissions()
        await refreshStoredKeyFlags()
        await refreshLifecycleState()
        if isArmed {
            do {
                try startForegroundListeningIfNeeded()
            } catch {
                errorMessage = userFacingErrorMessage(for: error)
            }
        }
    }

    func state(for kind: PermissionKind) -> PermissionState {
        permissionStates[kind] ?? .notDetermined
    }

    func request(_ kind: PermissionKind) async {
        guard isRequestingPermissions == false else {
            return
        }

        isRequestingPermissions = true
        defer { isRequestingPermissions = false }
        permissionStates[kind] = await permissionManager.request(kind)
        attemptListeningRecoveryAfterPermissionUpdate()
    }

    func requestAllPermissions() async {
        guard isRequestingPermissions == false else {
            return
        }

        isRequestingPermissions = true
        defer { isRequestingPermissions = false }
        for kind in PermissionKind.allCases {
            permissionStates[kind] = await permissionManager.request(kind)
        }
        attemptListeningRecoveryAfterPermissionUpdate()
    }

    func refreshPermissions() async {
        permissionStates = await permissionManager.refreshAllStates()
    }

    func saveKeys() async {
        do {
            if openAIKeyInput.isEmpty == false {
                let normalizedOpenAIKey = APIKeySanitizer.normalize(openAIKeyInput, provider: .openAI)
                guard securityPolicy.validateApiKeyFormat(provider: .openAI, key: normalizedOpenAIKey) else {
                    throw AgentError.invalidCredentialFormat(provider: .openAI)
                }
                try await credentialStore.setKey(normalizedOpenAIKey, for: .openAI)
                openAIKeyInput = normalizedOpenAIKey
            }

            if elevenLabsKeyInput.isEmpty == false {
                let normalizedElevenKey = APIKeySanitizer.normalize(elevenLabsKeyInput, provider: .elevenLabs)
                guard securityPolicy.validateApiKeyFormat(provider: .elevenLabs, key: normalizedElevenKey) else {
                    throw AgentError.invalidCredentialFormat(provider: .elevenLabs)
                }
                try await credentialStore.setKey(normalizedElevenKey, for: .elevenLabs)
                elevenLabsKeyInput = normalizedElevenKey
            }

            await refreshStoredKeyFlags()
            statusText = "API keys saved securely in Keychain."
        } catch {
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    func revealStoredKeys() async {
        do {
            let allowed = try await biometricAuthenticator.authenticate(reason: "Reveal saved provider keys")
            guard allowed else { return }

            openAIKeyInput = try await credentialStore.getKey(for: .openAI) ?? ""
            elevenLabsKeyInput = try await credentialStore.getKey(for: .elevenLabs) ?? ""
            statusText = "Stored keys loaded after authentication."
        } catch {
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    func openKeyManagement() {
        isKeyManagementPresented = true
    }

    func closeKeyManagement() {
        isKeyManagementPresented = false
    }

    func setPreferOnDeviceSpeech(_ enabled: Bool) {
        // Cloud TTS is intentionally disabled for stability in the current MVP.
        preferOnDeviceSpeech = true
        statusText = "On-device voice mode enabled."
    }

    func toggleArmState() async {
        do {
            if isArmed {
                cancelSpeechRecovery()
                transcriptDebounceTask?.cancel()
                playbackService.stopAllPlayback()
                speechListener.stop()
                await orchestrator.disarm()
                liveTranscript = ""
                lastUserUtterance = ""
                lastSubmittedUtterance = ""
                isAssistantSpeaking = false
                lastAssistantReplyForEchoFilter = ""
                suppressTranscriptUntil = Date.distantPast
                statusText = "Agent disarmed."
            } else {
                try await orchestrator.arm(modelId: selectedWakeModel)
                try startForegroundListeningIfNeeded()
                let microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
                let speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
                statusText = (microphoneGranted && speechGranted)
                    ? "Agent armed. Say wake phrase to start."
                    : "Agent armed. Grant microphone and speech permissions to listen."
            }
            await refreshLifecycleState()
        } catch {
            cancelSpeechRecovery()
            transcriptDebounceTask?.cancel()
            playbackService.stopAllPlayback()
            speechListener.stop()
            await orchestrator.disarm()
            isAssistantSpeaking = false
            await refreshLifecycleState()
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    func beginConversation() async {
        do {
            _ = try await orchestrator.beginConversation()
            await refreshLifecycleState()
            statusText = "Conversation started."
        } catch {
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    func endConversation() async {
        do {
            cancelSpeechRecovery()
            transcriptDebounceTask?.cancel()
            playbackService.stopAllPlayback()
            speechListener.stop()
            isAssistantSpeaking = false
            try await orchestrator.endConversation(
                summary: assistantReply.isEmpty ? nil : assistantReply,
                tags: ["ui-session"]
            )
            liveTranscript = ""
            lastUserUtterance = ""
            lastSubmittedUtterance = ""
            lastAssistantReplyForEchoFilter = ""
            suppressTranscriptUntil = Date.distantPast
            await refreshLifecycleState()
            statusText = "Conversation ended."
        } catch {
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        Task {
            switch phase {
            case .active:
                await lifecycleController.handleScenePhaseChange(.active)
                await refreshPermissions()
            case .inactive:
                await lifecycleController.handleScenePhaseChange(.inactive)
            case .background:
                cancelSpeechRecovery()
                transcriptDebounceTask?.cancel()
                speechListener.stop()
                await lifecycleController.handleScenePhaseChange(.background)
            @unknown default:
                await lifecycleController.handleScenePhaseChange(.inactive)
            }

            await refreshLifecycleState()
            if phase == .active, isArmed {
                do {
                    try startForegroundListeningIfNeeded()
                } catch {
                    errorMessage = userFacingErrorMessage(for: error)
                }
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func refreshStoredKeyFlags() async {
        do {
            hasStoredOpenAIKey = try await credentialStore.getKey(for: .openAI) != nil
            hasStoredElevenLabsKey = try await credentialStore.getKey(for: .elevenLabs) != nil
        } catch {
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    private func refreshLifecycleState() async {
        let state = await orchestrator.currentState()
        applyLifecycleState(state)
    }

    private func applyLifecycleState(_ state: AgentLifecycleState) {
        switch state {
        case .disarmed:
            isArmed = false
            isConversing = false
            lifecycleStateText = "disarmed"
        case .armedForeground(let modelId):
            isArmed = true
            isConversing = false
            lifecycleStateText = "armedForeground(\(modelId))"
        case .conversing(let sessionID):
            isArmed = true
            isConversing = true
            lifecycleStateText = "conversing(\(sessionID.uuidString.prefix(8)))"
        case .backgroundSuspended(let previousModelId):
            isArmed = false
            isConversing = false
            lifecycleStateText = "backgroundSuspended(\(previousModelId ?? "none"))"
        }
    }

    private func startForegroundListeningIfNeeded() throws {
        let microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
        let speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        guard microphoneGranted, speechGranted else {
            cancelSpeechRecovery()
            return
        }

        guard isArmed else {
            cancelSpeechRecovery()
            return
        }

        guard speechListener.isListening == false else {
            speechRecoveryAttempt = 0
            return
        }

        try speechListener.start(
            onTranscript: { [weak self] transcript in
                guard let self else { return }
                Task { await self.consumeTranscript(transcript) }
            },
            onError: { [weak self] error in
                guard let self else { return }
                Task { @MainActor in
                    self.handleSpeechListenerError(error)
                }
            }
        )
        speechRecoveryAttempt = 0
    }

    private func consumeTranscript(_ transcript: String) async {
        let normalizedTranscript = normalizeTranscriptText(transcript)
        guard normalizedTranscript.isEmpty == false else {
            return
        }

        if shouldIgnoreTranscriptAsEcho(normalizedTranscript) {
            return
        }

        if isAssistantSpeaking, shouldInterruptAssistantSpeech(with: normalizedTranscript) {
            playbackService.stopAllPlayback(deactivateAudioSession: false)
            isAssistantSpeaking = false
            statusText = "Speech interrupted by user."
        }

        liveTranscript = normalizedTranscript
        let wasConversing = isConversing
        await orchestrator.ingestTranscript(normalizedTranscript)

        let state = await orchestrator.currentState()
        applyLifecycleState(state)

        if wasConversing == false, isConversing {
            lastSubmittedUtterance = ""
            statusText = "Wake phrase detected. Listening..."
        }

        guard isConversing else {
            return
        }

        scheduleVoiceTurnProcessing(transcript: normalizedTranscript)
    }

    private func scheduleVoiceTurnProcessing(transcript: String) {
        transcriptDebounceTask?.cancel()
        transcriptDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(850))
            guard Task.isCancelled == false else {
                return
            }
            await self?.processVoiceTurn(from: transcript)
        }
    }

    private func processVoiceTurn(from transcript: String) async {
        guard isConversing else {
            return
        }

        guard isHandlingVoiceTurn == false else {
            return
        }

        let utterance = sanitizeUserUtterance(transcript)
        guard utterance.count >= 2 else {
            return
        }

        guard utterance != lastSubmittedUtterance else {
            return
        }

        isHandlingVoiceTurn = true
        defer { isHandlingVoiceTurn = false }

        lastSubmittedUtterance = utterance
        lastUserUtterance = utterance
        statusText = "Thinking..."

        do {
            let response: LLMResponse
            do {
                response = try await orchestrator.sendText(utterance)
            } catch {
                throw mapModelStageError(error)
            }

            assistantReply = response.text
            lastAssistantReplyForEchoFilter = normalizeForEchoComparison(response.text)
            statusText = "Replying..."

            do {
                try startForegroundListeningIfNeeded()
            } catch {
                restartForegroundListeningWithRecovery(error)
            }

            isAssistantSpeaking = true
            defer { isAssistantSpeaking = false }
            try await playSpeechWithFallback(text: response.text)
            suppressTranscriptUntil = Date().addingTimeInterval(1.2)
            statusText = "Listening for follow-up..."
        } catch {
            isAssistantSpeaking = false
            errorMessage = userFacingErrorMessage(for: error)
            statusText = "Voice turn failed. Listening..."
        }

        do {
            try startForegroundListeningIfNeeded()
        } catch {
            restartForegroundListeningWithRecovery(error)
        }
    }

    private func sanitizeUserUtterance(_ transcript: String) -> String {
        var sanitized = transcript

        for phrase in wakePhrases(for: selectedWakeModel) {
            sanitized = sanitized.replacingOccurrences(
                of: phrase,
                with: "",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }

        let punctuationToSpace = ["，", "。", ",", ".", "!", "！", "?", "？", "\n", "\t"]
        for token in punctuationToSpace {
            sanitized = sanitized.replacingOccurrences(of: token, with: " ")
        }

        return normalizeTranscriptText(sanitized)
    }

    private func wakePhrases(for modelId: String) -> [String] {
        WakeWordModel.presets.first(where: { $0.id == modelId })?.triggerPhrases ?? []
    }

    private func playSpeechWithFallback(text: String) async throws {
        try await playbackService.speakOnDevice(
            text: text,
            languageCode: selectedWakeModel.hasSuffix("-cn") ? "zh-CN" : "en-US"
        )
        statusText = "Replying with on-device voice."
    }

    private func mapModelStageError(_ error: Error) -> Error {
        guard let agentError = error as? AgentError else {
            return error
        }
        guard case .networkFailure(let code) = agentError, code == 401 else {
            return error
        }
        return AgentError.other(
            message: "OpenAI authentication failed (401). Please re-save a valid OpenAI API key in Key Management."
        )
    }

    private func normalizeTranscriptText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleSpeechListenerError(_ error: Error) {
        guard isArmed else {
            return
        }

        let microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
        let speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        guard microphoneGranted, speechGranted else {
            errorMessage = userFacingErrorMessage(for: error)
            return
        }

        if isRecoverableSpeechListenerError(error) {
            scheduleSpeechRecovery()
            return
        }

        errorMessage = userFacingErrorMessage(for: error)
    }

    private func restartForegroundListeningWithRecovery(_ error: Error) {
        if isRecoverableSpeechListenerError(error) {
            scheduleSpeechRecovery()
            return
        }
        errorMessage = userFacingErrorMessage(for: error)
    }

    private func attemptListeningRecoveryAfterPermissionUpdate() {
        guard isArmed else {
            return
        }

        do {
            try startForegroundListeningIfNeeded()
        } catch {
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    private func isRecoverableSpeechListenerError(_ error: Error) -> Bool {
        if let listenerError = error as? ForegroundSpeechListenerError {
            switch listenerError {
            case .microphonePermissionRequired, .speechPermissionRequired, .recognizerUnavailable:
                return false
            case .recognizerNotAvailableNow,
                    .audioInputUnavailable,
                    .couldNotConfigureAudioSession,
                    .couldNotStartEngine:
                return true
            }
        }

        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain" || nsError.domain == "SFSpeechErrorDomain" {
            return true
        }

        if nsError.domain.lowercased().contains("avaudiosession") {
            return true
        }

        return false
    }

    private func scheduleSpeechRecovery() {
        guard isArmed else {
            return
        }
        guard isHandlingVoiceTurn == false else {
            return
        }

        speechRecoveryTask?.cancel()
        speechRecoveryAttempt += 1
        let delayMs = min(2200, 300 * max(1, speechRecoveryAttempt))
        statusText = "Mic interrupted. Reconnecting..."

        speechRecoveryTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard Task.isCancelled == false else {
                return
            }

            guard let self else {
                return
            }

            await MainActor.run {
                do {
                    try self.startForegroundListeningIfNeeded()
                    if self.isConversing {
                        self.statusText = "Listening for follow-up..."
                    } else {
                        self.statusText = "Listening for wake phrase..."
                    }
                } catch {
                    if self.isRecoverableSpeechListenerError(error), self.speechRecoveryAttempt < 8 {
                        self.scheduleSpeechRecovery()
                    } else {
                        self.errorMessage = self.userFacingErrorMessage(for: error)
                    }
                }
            }
        }
    }

    private func cancelSpeechRecovery() {
        speechRecoveryTask?.cancel()
        speechRecoveryTask = nil
        speechRecoveryAttempt = 0
    }

    private func userFacingErrorMessage(for error: Error) -> String {
        if let agentError = error as? AgentError {
            switch agentError {
            case .invalidStateTransition(_, let action):
                return "Action '\(action)' is unavailable in current state. Please arm the agent first."
            case .missingCredential(let provider):
                return "Missing API key for \(provider.rawValue). Please save it in Key Management."
            case .invalidCredentialFormat(let provider):
                return "The \(provider.rawValue) API key format looks invalid. Please verify and retry."
            case .runtimeRiskDetected(let reasons):
                return "Runtime risk detected: \(reasons.joined(separator: ", ")). Agent features were degraded for safety."
            case .modelNotFound(let modelId):
                return "Wake model '\(modelId)' was not found."
            case .providerNotConnected:
                return "Model connection is not ready. Please try again; the app will reconnect automatically."
            case .storageCorrupted:
                return "Local secure storage appears corrupted. Please reset local data."
            case .unsupportedResponse:
                return "Provider returned an unsupported response format."
            case .networkFailure(let code):
                if code == 401 {
                    return "Authentication failed (401). Please verify your OpenAI API key in Key Management."
                }
                return "Network request failed with status code \(code)."
            case .other(let message):
                return message
            }
        }

        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }

        return error.localizedDescription
    }

    private func shouldIgnoreTranscriptAsEcho(_ transcript: String) -> Bool {
        if Date() < suppressTranscriptUntil {
            return true
        }

        guard isConversing else {
            return false
        }

        let candidate = normalizeForEchoComparison(transcript)
        guard candidate.isEmpty == false, lastAssistantReplyForEchoFilter.isEmpty == false else {
            return false
        }

        if candidate.count >= 6, lastAssistantReplyForEchoFilter.contains(candidate) {
            return true
        }

        let prefixLength = min(18, lastAssistantReplyForEchoFilter.count)
        if prefixLength >= 6 {
            let prefix = String(lastAssistantReplyForEchoFilter.prefix(prefixLength))
            if candidate.contains(prefix) {
                return true
            }
        }

        return false
    }

    private func shouldInterruptAssistantSpeech(with transcript: String) -> Bool {
        let candidate = normalizeForEchoComparison(transcript)
        guard candidate.count >= 4 else {
            return false
        }

        guard lastAssistantReplyForEchoFilter.isEmpty == false else {
            return true
        }

        if lastAssistantReplyForEchoFilter.contains(candidate) {
            return false
        }

        let prefixLength = min(18, lastAssistantReplyForEchoFilter.count)
        if prefixLength >= 6 {
            let prefix = String(lastAssistantReplyForEchoFilter.prefix(prefixLength))
            if candidate.contains(prefix) {
                return false
            }
        }

        return true
    }

    private func normalizeForEchoComparison(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[\\p{Punct}\\p{Symbol}\\s]+", with: "", options: .regularExpression)
    }
}
