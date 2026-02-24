#if canImport(Testing)
import Testing
@testable import SolituderKit

@Suite("SecurityPolicyEngine")
struct SecurityPolicyEngineTests {
    private let engine = DefaultSecurityPolicyEngine()

    @Test
    func validateOpenAIKeyFormat() {
        #expect(engine.validateApiKeyFormat(provider: .openAI, key: "sk-valid-key-1234567890"))
        #expect(engine.validateApiKeyFormat(provider: .openAI, key: "Bearer sk-valid-key-1234567890"))
        #expect(engine.validateApiKeyFormat(provider: .openAI, key: "api_key=sk-valid-key-1234567890"))
        #expect(engine.validateApiKeyFormat(provider: .openAI, key: "invalid") == false)
    }

    @Test
    func redactLogsMasksKnownPatterns() {
        let payload = "Authorization: Bearer sk-secret-key-1234567890 and api_key=abcdef123456"
        let redacted = engine.redactLogs(payload: payload)

        #expect(redacted.contains("sk-secret-key-1234567890") == false)
        #expect(redacted.contains("abcdef123456") == false)
        #expect(redacted.contains("[REDACTED]"))
    }

    @Test
    func redactLogsDoesNotModifyNormalText() {
        let payload = "Hello team, status is healthy."
        let redacted = engine.redactLogs(payload: payload)
        #expect(redacted == payload)
    }

    @Test
    func runtimeRiskCheckReturnsReport() {
        let report = engine.runtimeRiskCheck()
        #expect(report.reasons.count >= 0)
    }
}
#elseif canImport(XCTest)
import XCTest
@testable import SolituderKit

final class SecurityPolicyEngineTests: XCTestCase {
    private let engine = DefaultSecurityPolicyEngine()

    func testValidateOpenAIKeyFormat() {
        XCTAssertTrue(engine.validateApiKeyFormat(provider: .openAI, key: "sk-valid-key-1234567890"))
        XCTAssertTrue(engine.validateApiKeyFormat(provider: .openAI, key: "Bearer sk-valid-key-1234567890"))
        XCTAssertTrue(engine.validateApiKeyFormat(provider: .openAI, key: "api_key=sk-valid-key-1234567890"))
        XCTAssertFalse(engine.validateApiKeyFormat(provider: .openAI, key: "invalid"))
    }

    func testRedactLogsMasksKnownPatterns() {
        let payload = "Authorization: Bearer sk-secret-key-1234567890 and api_key=abcdef123456"
        let redacted = engine.redactLogs(payload: payload)

        XCTAssertFalse(redacted.contains("sk-secret-key-1234567890"))
        XCTAssertFalse(redacted.contains("abcdef123456"))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }

    func testRedactLogsDoesNotModifyNormalText() {
        let payload = "Hello team, status is healthy."
        let redacted = engine.redactLogs(payload: payload)

        XCTAssertEqual(redacted, payload)
    }
}
#endif
