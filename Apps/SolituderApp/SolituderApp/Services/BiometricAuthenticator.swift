import Foundation
import LocalAuthentication

protocol BiometricAuthenticating: Sendable {
    func authenticate(reason: String) async throws -> Bool
}

enum BiometricAuthError: LocalizedError {
    case unavailable(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return "Authentication unavailable: \(message)"
        case .failed(let message):
            return "Authentication failed: \(message)"
        }
    }
}

struct LocalBiometricAuthenticator: BiometricAuthenticating {
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var authError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            throw BiometricAuthError.unavailable(authError?.localizedDescription ?? "No supported authentication policy")
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: BiometricAuthError.failed(error.localizedDescription))
                    return
                }
                continuation.resume(returning: success)
            }
        }
    }
}
