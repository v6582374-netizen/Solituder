import Foundation

public enum AgentError: Error, Equatable {
    case invalidStateTransition(from: AgentLifecycleState, action: String)
    case missingCredential(provider: CredentialProvider)
    case invalidCredentialFormat(provider: CredentialProvider)
    case runtimeRiskDetected(reasons: [String])
    case modelNotFound(modelId: String)
    case providerNotConnected
    case storageCorrupted
    case unsupportedResponse
    case networkFailure(code: Int)
    case other(message: String)
}
