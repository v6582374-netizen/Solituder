import AVFoundation
import Foundation
import Speech
import UserNotifications

final class SystemPermissionManager: PermissionManaging, @unchecked Sendable {
    func currentState(for kind: PermissionKind) async -> PermissionState {
        switch kind {
        case .microphone:
            return microphoneState(from: AVAudioSession.sharedInstance().recordPermission)
        case .speechRecognition:
            return Self.speechState(from: SFSpeechRecognizer.authorizationStatus())
        case .notifications:
            return await notificationState()
        }
    }

    func request(_ kind: PermissionKind) async -> PermissionState {
        switch kind {
        case .microphone:
            return await requestMicrophone()
        case .speechRecognition:
            return await requestSpeechRecognition()
        case .notifications:
            return await requestNotifications()
        }
    }

    func refreshAllStates() async -> [PermissionKind: PermissionState] {
        var result: [PermissionKind: PermissionState] = [:]
        for kind in PermissionKind.allCases {
            result[kind] = await currentState(for: kind)
        }
        return result
    }

    private func microphoneState(from permission: AVAudioSession.RecordPermission) -> PermissionState {
        switch permission {
        case .undetermined:
            return .notDetermined
        case .granted:
            return .granted
        case .denied:
            return .denied
        @unknown default:
            return .restricted
        }
    }

    private static func speechState(from status: SFSpeechRecognizerAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    private func requestMicrophone() async -> PermissionState {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    private func requestSpeechRecognition() async -> PermissionState {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: Self.speechState(from: status))
            }
        }
    }

    private func notificationState() async -> PermissionState {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let state: PermissionState
                switch settings.authorizationStatus {
                case .notDetermined:
                    state = .notDetermined
                case .denied:
                    state = .denied
                case .authorized, .provisional, .ephemeral:
                    state = .granted
                @unknown default:
                    state = .restricted
                }
                continuation.resume(returning: state)
            }
        }
    }

    private func requestNotifications() async -> PermissionState {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted ? .granted : .denied)
            }
        }
    }
}
