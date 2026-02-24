import CryptoKit
import Foundation
import Security

public actor EncryptedLocalMemoryStore: LocalMemoryStore {
    private let fileURL: URL
    private let keychainService: String
    private let keychainAccount = "memory-encryption-key"
    private var cachedKey: SymmetricKey?

    public init(
        baseDirectory: URL? = nil,
        fileName: String = "memory_store.bin",
        keychainService: String = "com.solituder.memory"
    ) {
        let directory = baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = directory.appendingPathComponent(fileName)
        self.keychainService = keychainService
    }

    public func saveSummary(sessionId: UUID, summary: String, tags: [String]) async throws {
        var records = try loadRecords()
        records.append(MemoryRecord(sessionID: sessionId, summary: summary, tags: tags))
        try persist(records)
    }

    public func query(context: MemoryQueryContext) async throws -> [MemoryRecord] {
        let records = try loadRecords()
        guard context.keywords.isEmpty == false else {
            return Array(records.sorted(by: { $0.createdAt > $1.createdAt }).prefix(context.limit))
        }

        let lowered = context.keywords.map { $0.lowercased() }
        let matched = records.filter { record in
            let summary = record.summary.lowercased()
            let tags = record.tags.map { $0.lowercased() }
            return lowered.contains { keyword in
                summary.contains(keyword) || tags.contains(keyword)
            }
        }

        return Array(matched.sorted(by: { $0.createdAt > $1.createdAt }).prefix(context.limit))
    }

    public func deleteAll() async throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func loadRecords() throws -> [MemoryRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let encrypted = try Data(contentsOf: fileURL)
        guard encrypted.isEmpty == false else {
            return []
        }

        let key = try loadOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encrypted)
        let plaintext = try AES.GCM.open(sealedBox, using: key)

        return try JSONDecoder().decode([MemoryRecord].self, from: plaintext)
    }

    private func persist(_ records: [MemoryRecord]) throws {
        let key = try loadOrCreateKey()
        let payload = try JSONEncoder().encode(records)
        let sealed = try AES.GCM.seal(payload, using: key)

        guard let combined = sealed.combined else {
            throw AgentError.storageCorrupted
        }

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try combined.write(to: fileURL, options: [.atomic])
    }

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let cachedKey {
            return cachedKey
        }

        if let existing = try readKeychainData(), existing.count == 32 {
            let key = SymmetricKey(data: existing)
            cachedKey = key
            return key
        }

        var keyData = Data(count: 32)
        let status = keyData.withUnsafeMutableBytes { rawBuffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, rawBuffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw AgentError.other(message: "Unable to generate encryption key")
        }

        try writeKeychainData(keyData)

        let key = SymmetricKey(data: keyData)
        cachedKey = key
        return key
    }

    private func readKeychainData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
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

        guard let data = item as? Data else {
            throw AgentError.storageCorrupted
        }

        return data
    }

    private func writeKeychainData(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AgentError.other(message: "Keychain write failed: \(status)")
        }
    }
}
