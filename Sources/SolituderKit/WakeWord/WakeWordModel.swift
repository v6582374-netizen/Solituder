import Foundation

public struct WakeWordModel: Equatable, Sendable {
    public let id: String
    public let triggerPhrases: [String]

    public init(id: String, triggerPhrases: [String]) {
        self.id = id
        self.triggerPhrases = triggerPhrases
    }

    public static let presets: [WakeWordModel] = [
        WakeWordModel(
            id: "jarvis-cn",
            triggerPhrases: ["你好贾维斯", "嘿贾维斯", "贾维斯", "杰维斯", "jarvis", "javis", "hey jarvis", "hey javis"]
        ),
        WakeWordModel(id: "jarvis-en", triggerPhrases: ["hey jarvis", "ok jarvis", "jarvis", "hey javis", "ok javis", "javis"]),
        WakeWordModel(id: "solituder-cn", triggerPhrases: ["你好孤旅", "孤旅助手"]),
        WakeWordModel(id: "solituder-en", triggerPhrases: ["hello solituder", "ok solituder"])
    ]
}
