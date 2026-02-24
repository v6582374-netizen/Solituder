import Darwin
import Foundation

public struct DefaultSecurityPolicyEngine: SecurityPolicyEngine {
    public init() {}

    public func validateApiKeyFormat(provider: CredentialProvider, key: String) -> Bool {
        let normalized = APIKeySanitizer.normalize(key, provider: provider)
        switch provider {
        case .openAI:
            return normalized.hasPrefix("sk-") && normalized.count >= 20
        case .elevenLabs:
            return normalized.count >= 20
                && normalized.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
        }
    }

    public func redactLogs(payload: String) -> String {
        let replacements: [(pattern: String, replacement: String)] = [
            ("sk-[A-Za-z0-9_-]{10,}", "[REDACTED]"),
            ("(?i)(api[_-]?key\\s*[:=]\\s*)[A-Za-z0-9_-]{8,}", "$1[REDACTED]")
        ]

        return replacements.reduce(payload) { partial, entry in
            partial.replacingOccurrences(
                of: entry.pattern,
                with: entry.replacement,
                options: .regularExpression
            )
        }
    }

    public func runtimeRiskCheck() -> RuntimeRiskReport {
        var reasons: [String] = []
        let debuggerAttached = isDebuggerAttached()
        let tampered = isTamperedEnvironment(reasons: &reasons)

        if debuggerAttached {
            reasons.append("Debugger attached")
        }

        return RuntimeRiskReport(
            isDebuggerAttached: debuggerAttached,
            isJailbrokenOrTampered: tampered,
            reasons: reasons
        )
    }

    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride

        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        guard result == 0 else {
            return false
        }

        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    private func isTamperedEnvironment(reasons: inout [String]) -> Bool {
        var compromised = false

        #if os(iOS)
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]

        for path in suspiciousPaths where FileManager.default.fileExists(atPath: path) {
            reasons.append("Suspicious path found: \(path)")
            compromised = true
        }

        let probePath = "/private/solituder_jailbreak_probe.txt"
        do {
            try "probe".write(toFile: probePath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: probePath)
            reasons.append("Sandbox escape probe succeeded")
            compromised = true
        } catch {
            // Expected on non-jailbroken devices.
        }
        #endif

        if ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"] != nil {
            reasons.append("Dynamic library injection detected")
            compromised = true
        }

        return compromised
    }
}
