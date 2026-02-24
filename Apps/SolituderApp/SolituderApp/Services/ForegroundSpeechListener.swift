import AVFoundation
import Foundation
import Speech

protocol ForegroundSpeechListening {
    var isListening: Bool { get }
    func start(
        onTranscript: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) throws
    func stop()
}

enum ForegroundSpeechListenerError: LocalizedError {
    case microphonePermissionRequired
    case speechPermissionRequired
    case recognizerUnavailable
    case recognizerNotAvailableNow
    case audioInputUnavailable
    case couldNotConfigureAudioSession
    case couldNotStartEngine

    var errorDescription: String? {
        switch self {
        case .microphonePermissionRequired:
            return "Microphone permission is required before starting foreground listening."
        case .speechPermissionRequired:
            return "Speech recognition permission is required before starting foreground listening."
        case .recognizerUnavailable:
            return "No speech recognizer is available for the current locale."
        case .recognizerNotAvailableNow:
            return "Speech recognizer is temporarily unavailable. Please try again in a moment."
        case .audioInputUnavailable:
            return "Audio input is unavailable on this device right now."
        case .couldNotConfigureAudioSession:
            return "Could not configure audio session for listening."
        case .couldNotStartEngine:
            return "Could not start microphone capture."
        }
    }
}

final class ForegroundSpeechListener: ForegroundSpeechListening {
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var activeRecognitionID: UUID?
    private var hasInputTap = false

    private var listeningRequested = false
    var isListening: Bool {
        listeningRequested
            && audioEngine.isRunning
            && recognitionTask != nil
            && recognitionRequest != nil
    }

    func start(
        onTranscript: @escaping @Sendable (String) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) throws {
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            throw ForegroundSpeechListenerError.microphonePermissionRequired
        }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw ForegroundSpeechListenerError.speechPermissionRequired
        }

        stop()

        let recognizer = Self.makeRecognizer()
        guard let recognizer else {
            throw ForegroundSpeechListenerError.recognizerUnavailable
        }

        guard recognizer.isAvailable else {
            throw ForegroundSpeechListenerError.recognizerNotAvailableNow
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        speechRecognizer = recognizer
        let activeRequest = request
        let recognitionID = UUID()
        activeRecognitionID = recognitionID

        do {
            try configureAudioSession()
        } catch {
            stop()
            throw ForegroundSpeechListenerError.couldNotConfigureAudioSession
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            stop()
            throw ForegroundSpeechListenerError.audioInputUnavailable
        }

        removeInputTapIfNeeded()
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            activeRequest.append(buffer)
        }
        hasInputTap = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            guard self.activeRecognitionID == recognitionID else {
                return
            }

            if let result {
                let transcript = result.bestTranscription.formattedString
                if transcript.isEmpty == false {
                    onTranscript(transcript)
                }
            }

            if let error {
                onError(error)
                self.stop()
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            stop()
            throw ForegroundSpeechListenerError.couldNotStartEngine
        }

        listeningRequested = true
    }

    func stop() {
        listeningRequested = false
        activeRecognitionID = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        removeInputTapIfNeeded()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func removeInputTapIfNeeded() {
        guard hasInputTap else {
            return
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        hasInputTap = false
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth, .duckOthers]
        )
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private static func makeRecognizer() -> SFSpeechRecognizer? {
        let preferredLocales = [
            Locale(identifier: Locale.preferredLanguages.first ?? Locale.current.identifier),
            Locale(identifier: "zh-CN"),
            Locale(identifier: "en-US")
        ]

        for locale in preferredLocales {
            if let recognizer = SFSpeechRecognizer(locale: locale) {
                return recognizer
            }
        }

        return SFSpeechRecognizer()
    }
}
