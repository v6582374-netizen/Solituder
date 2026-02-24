import Foundation
#if canImport(Testing)
import Testing
@testable import SolituderKit

@Suite("EncryptedLocalMemoryStore")
struct EncryptedLocalMemoryStoreTests {
    @Test
    func saveAndQueryRoundTrip() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = "com.solituder.memory.tests.\(UUID().uuidString)"
        let store = EncryptedLocalMemoryStore(baseDirectory: tempDir, keychainService: service)

        let sessionID = UUID()
        try await store.saveSummary(sessionId: sessionID, summary: "Buy milk tomorrow", tags: ["shopping"])
        try await store.saveSummary(sessionId: UUID(), summary: "Review sprint tasks", tags: ["work"])

        let result = try await store.query(context: MemoryQueryContext(keywords: ["milk"], limit: 5))

        #expect(result.count == 1)
        #expect(result.first?.sessionID == sessionID)
        #expect(result.first?.tags == ["shopping"])
    }

    @Test
    func deleteAllRemovesRecords() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = "com.solituder.memory.tests.\(UUID().uuidString)"
        let store = EncryptedLocalMemoryStore(baseDirectory: tempDir, keychainService: service)

        try await store.saveSummary(sessionId: UUID(), summary: "Summary", tags: [])
        try await store.deleteAll()

        let result = try await store.query(context: MemoryQueryContext(keywords: []))
        #expect(result.count == 0)
    }
}
#elseif canImport(XCTest)
import XCTest
@testable import SolituderKit

final class EncryptedLocalMemoryStoreTests: XCTestCase {
    func testSaveAndQueryRoundTrip() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = "com.solituder.memory.tests.\(UUID().uuidString)"
        let store = EncryptedLocalMemoryStore(baseDirectory: tempDir, keychainService: service)

        let sessionID = UUID()
        try await store.saveSummary(sessionId: sessionID, summary: "Buy milk tomorrow", tags: ["shopping"])
        try await store.saveSummary(sessionId: UUID(), summary: "Review sprint tasks", tags: ["work"])

        let result = try await store.query(context: MemoryQueryContext(keywords: ["milk"], limit: 5))

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.sessionID, sessionID)
        XCTAssertEqual(result.first?.tags, ["shopping"])
    }

    func testDeleteAllRemovesRecords() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = "com.solituder.memory.tests.\(UUID().uuidString)"
        let store = EncryptedLocalMemoryStore(baseDirectory: tempDir, keychainService: service)

        try await store.saveSummary(sessionId: UUID(), summary: "Summary", tags: [])
        try await store.deleteAll()

        let result = try await store.query(context: MemoryQueryContext(keywords: []))
        XCTAssertEqual(result.count, 0)
    }
}
#endif
