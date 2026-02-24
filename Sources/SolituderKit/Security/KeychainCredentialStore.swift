import Foundation
import Security

public final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let service: String

    public init(service: String = "com.solituder.credentials") {
        self.service = service
    }

    public func setKey(_ key: String, for provider: CredentialProvider) async throws {
        let normalizedKey = APIKeySanitizer.normalize(key, provider: provider)
        try removeKeyIfNeeded(for: provider)

        guard let data = normalizedKey.data(using: .utf8) else {
            throw AgentError.other(message: "Failed to encode key")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AgentError.other(message: "Keychain add failed: \(status)")
        }
    }

    public func getKey(for provider: CredentialProvider) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw AgentError.other(message: "Keychain read failed: \(status)")
        }

        guard
            let data = item as? Data,
            let key = String(data: data, encoding: .utf8)
        else {
            throw AgentError.storageCorrupted
        }

        let normalized = APIKeySanitizer.normalize(key, provider: provider)
        return normalized.isEmpty ? nil : normalized
    }

    public func removeKey(for provider: CredentialProvider) async throws {
        try removeKeyIfNeeded(for: provider)
    }

    private func removeKeyIfNeeded(for provider: CredentialProvider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw AgentError.other(message: "Keychain delete failed: \(status)")
        }
    }
}
