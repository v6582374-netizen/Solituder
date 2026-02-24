import Foundation

enum PermissionKind: String, CaseIterable, Identifiable {
    case microphone
    case speechRecognition
    case notifications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone:
            return "Microphone"
        case .speechRecognition:
            return "Speech Recognition"
        case .notifications:
            return "Notifications"
        }
    }

    var detail: String {
        switch self {
        case .microphone:
            return "Needed to capture voice prompts while app is active."
        case .speechRecognition:
            return "Needed to transcribe spoken requests."
        case .notifications:
            return "Optional. Used for reminders and status prompts."
        }
    }
}

enum PermissionState: String {
    case notDetermined
    case granted
    case denied
    case restricted

    var title: String {
        switch self {
        case .notDetermined:
            return "Not Requested"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        }
    }
}

protocol PermissionManaging: Sendable {
    func currentState(for kind: PermissionKind) async -> PermissionState
    func request(_ kind: PermissionKind) async -> PermissionState
    func refreshAllStates() async -> [PermissionKind: PermissionState]
}
