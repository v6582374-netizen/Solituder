import Foundation

public struct NetworkDomainAllowlist: Sendable {
    private let hosts: Set<String>

    public init(hosts: Set<String>) {
        self.hosts = hosts
    }

    public func validate(url: URL) throws {
        guard let host = url.host?.lowercased() else {
            throw AgentError.other(message: "URL host missing")
        }

        guard hosts.contains(host) else {
            throw AgentError.other(message: "Blocked network host: \(host)")
        }
    }

    public static let defaultModelHosts = NetworkDomainAllowlist(hosts: [
        "api.openai.com",
        "api.elevenlabs.io"
    ])
}
