import Foundation

public enum APIKeySanitizer {
    public static func normalize(_ raw: String, provider: CredentialProvider) -> String {
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle common copy/paste variants from docs or env files.
        if key.lowercased().hasPrefix("authorization:") {
            key = String(key.drop(while: { $0 != " " })).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if key.lowercased().hasPrefix("bearer ") {
            key = String(key.dropFirst("bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if key.lowercased().hasPrefix("api_key=") {
            key = String(key.dropFirst("api_key=".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if key.lowercased().hasPrefix("openai_api_key=") {
            key = String(key.dropFirst("openai_api_key=".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if key.lowercased().hasPrefix("elevenlabs_api_key=") {
            key = String(key.dropFirst("elevenlabs_api_key=".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        key = key.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        key = key.replacingOccurrences(of: "\u{200B}", with: "")
        key = key.replacingOccurrences(of: "\u{FEFF}", with: "")

        switch provider {
        case .openAI:
            if let match = key.range(of: "sk-[A-Za-z0-9_-]{20,}", options: .regularExpression) {
                return String(key[match])
            }
        case .elevenLabs:
            if let match = key.range(of: "[A-Za-z0-9_-]{20,}", options: .regularExpression) {
                return String(key[match])
            }
        }

        return key
    }
}
