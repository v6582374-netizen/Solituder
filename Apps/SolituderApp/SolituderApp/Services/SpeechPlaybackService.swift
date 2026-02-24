import AVFoundation
import Foundation
import SolituderKit

enum SpeechPlaybackError: LocalizedError {
    case emptyAudio
    case couldNotStartPlayback
    case playbackInterrupted
    case emptySpeechText
    case couldNotStartLocalSpeech

    var errorDescription: String? {
        switch self {
        case .emptyAudio:
            return "No audio was returned by speech provider."
        case .couldNotStartPlayback:
            return "Unable to start voice playback."
        case .playbackInterrupted:
            return "Playback was interrupted."
        case .emptySpeechText:
            return "No text was provided for speech."
        case .couldNotStartLocalSpeech:
            return "Unable to start on-device speech."
        }
    }
}

@MainActor
final class SpeechPlaybackService: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    private var player: AVAudioPlayer?
    private var completionContinuation: CheckedContinuation<Void, Error>?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechContinuation: CheckedContinuation<Void, Error>?
    private var speechStartTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func stopAllPlayback(deactivateAudioSession: Bool = true) {
        speechStartTimeoutTask?.cancel()
        speechStartTimeoutTask = nil

        if player?.isPlaying == true {
            player?.stop()
        }
        player = nil

        if speechSynthesizer.isSpeaking || speechSynthesizer.isPaused {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        resolvePlayback(with: .success(()))
        resolveSpeech(with: .success(()))
        if deactivateAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func play(stream: AudioBufferStream) async throws {
        var audio = Data()
        for try await chunk in stream {
            audio.append(chunk)
        }

        guard audio.isEmpty == false else {
            throw SpeechPlaybackError.emptyAudio
        }

        resolvePlayback(with: .failure(SpeechPlaybackError.playbackInterrupted))
        player?.stop()

        let player = try AVAudioPlayer(data: audio)
        player.delegate = self
        player.prepareToPlay()

        guard player.play() else {
            throw SpeechPlaybackError.couldNotStartPlayback
        }

        self.player = player
        try await withCheckedThrowingContinuation { continuation in
            completionContinuation = continuation
        }
    }

    func speakOnDevice(text: String, languageCode: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw SpeechPlaybackError.emptySpeechText
        }

        resolveSpeech(with: .failure(SpeechPlaybackError.playbackInterrupted))
        speechStartTimeoutTask?.cancel()
        speechStartTimeoutTask = nil
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        try configureSpeechAudioSession()

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
            ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        try await withCheckedThrowingContinuation { continuation in
            speechContinuation = continuation
            speechSynthesizer.speak(utterance)
            scheduleSpeechStartTimeout()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.player = nil
            if flag {
                self.resolvePlayback(with: .success(()))
            } else {
                self.resolvePlayback(with: .failure(SpeechPlaybackError.couldNotStartPlayback))
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.player = nil
            self.resolvePlayback(with: .failure(SpeechPlaybackError.couldNotStartPlayback))
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.resolveSpeech(with: .success(()))
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.speechStartTimeoutTask?.cancel()
            self?.speechStartTimeoutTask = nil
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.resolveSpeech(with: .failure(SpeechPlaybackError.playbackInterrupted))
        }
    }

    private func resolvePlayback(with result: Result<Void, Error>) {
        guard let completionContinuation else {
            return
        }

        self.completionContinuation = nil
        switch result {
        case .success:
            completionContinuation.resume()
        case .failure(let error):
            completionContinuation.resume(throwing: error)
        }
    }

    private func resolveSpeech(with result: Result<Void, Error>) {
        speechStartTimeoutTask?.cancel()
        speechStartTimeoutTask = nil

        guard let speechContinuation else {
            return
        }

        self.speechContinuation = nil
        switch result {
        case .success:
            speechContinuation.resume()
        case .failure(let error):
            speechContinuation.resume(throwing: error)
        }
    }

    private func configureSpeechAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth, .duckOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func scheduleSpeechStartTimeout() {
        speechStartTimeoutTask?.cancel()
        speechStartTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard Task.isCancelled == false else {
                return
            }
            await MainActor.run {
                guard let self else {
                    return
                }
                if self.speechSynthesizer.isSpeaking == false && self.speechSynthesizer.isPaused == false {
                    self.resolveSpeech(with: .failure(SpeechPlaybackError.couldNotStartLocalSpeech))
                }
            }
        }
    }
}
