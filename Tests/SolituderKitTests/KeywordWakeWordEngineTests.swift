#if canImport(Testing)
import Testing
@testable import SolituderKit

@Suite("KeywordWakeWordEngine")
struct KeywordWakeWordEngineTests {
    @Test
    func onlyActiveModelTriggersDetections() async throws {
        let engine = KeywordWakeWordEngine(models: [
            WakeWordModel(id: "a", triggerPhrases: ["hello a"]),
            WakeWordModel(id: "b", triggerPhrases: ["hello b"])
        ])
        let capture = DetectionCapture()

        await engine.onDetected { event in
            Task {
                await capture.store(event: event)
            }
        }

        try await engine.start(modelId: "a")
        await engine.processTranscript("hello b")

        try await engine.start(modelId: "b")
        await engine.processTranscript("hello b")

        try await Task.sleep(for: .milliseconds(20))

        let events = await capture.events()
        #expect(events.count == 1)
        #expect(events.first?.modelId == "b")
        #expect(events.first?.phrase == "hello b")
    }

    private actor DetectionCapture {
        private var values: [WakeWordDetectionEvent] = []

        func store(event: WakeWordDetectionEvent) {
            values.append(event)
        }

        func events() -> [WakeWordDetectionEvent] {
            values
        }
    }
}
#elseif canImport(XCTest)
import XCTest
@testable import SolituderKit

final class KeywordWakeWordEngineTests: XCTestCase {
    func testOnlyActiveModelTriggersDetections() async throws {
        let engine = KeywordWakeWordEngine(models: [
            WakeWordModel(id: "a", triggerPhrases: ["hello a"]),
            WakeWordModel(id: "b", triggerPhrases: ["hello b"])
        ])

        let expectation = expectation(description: "Detection callback")
        expectation.expectedFulfillmentCount = 1

        await engine.onDetected { event in
            XCTAssertEqual(event.modelId, "b")
            XCTAssertEqual(event.phrase, "hello b")
            expectation.fulfill()
        }

        try await engine.start(modelId: "a")
        await engine.processTranscript("hello b")

        try await engine.start(modelId: "b")
        await engine.processTranscript("hello b")

        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
#endif
