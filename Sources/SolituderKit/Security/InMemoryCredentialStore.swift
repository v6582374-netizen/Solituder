import Foundation

public actor InMemoryCredentialStore: CredentialStore {
    private var storage: [CredentialProvider: String] = [:]

    public init() {}

    public func setKey(_ key: String, for provider: CredentialProvider) async throws {
        storage[provider] = APIKeySanitizer.normalize(key, provider: provider)
    }

    public func getKey(for provider: CredentialProvider) async throws -> String? {
        guard let key = storage[provider] else {
            return nil
        }
        return APIKeySanitizer.normalize(key, provider: provider)
    }

    public func removeKey(for provider: CredentialProvider) async throws {
        storage[provider] = nil
    }
}
