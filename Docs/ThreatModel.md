# Threat Model (MVP Baseline)

## Method

- STRIDE analysis.
- Data flow review for wake-word, LLM, TTS, and memory.

## Assets

- User API keys (OpenAI, ElevenLabs).
- Conversation summaries in local memory.
- Audio pipeline metadata and runtime session IDs.

## Trust boundaries

1. Device local runtime.
2. Keychain and encrypted filesystem boundary.
3. External model and speech provider APIs.

## Threats and controls

1. Spoofing
- Threat: forged provider endpoint.
- Control: allowlist trusted hostnames and enforce TLS.

2. Tampering
- Threat: local memory file manipulation.
- Control: AES-GCM authenticated encryption and decode validation.

3. Repudiation
- Threat: inability to audit state transitions.
- Control: redacted structured logs for orchestrator lifecycle.

4. Information Disclosure
- Threat: API key leakage in logs.
- Control: `SecurityPolicyEngine.redactLogs(payload:)` and no plaintext persistence.

5. Denial of Service
- Threat: unstable network or provider outage.
- Control: HTTP fallback path and explicit error states.

6. Elevation of Privilege
- Threat: jailbreak/debugger assisted runtime abuse.
- Control: runtime risk checks with capability degradation.

## Open risks for production hardening

- Certificate pinning policy and key rotation workflow.
- Provider rate-limit abuse detection.
- Automated MASVS verification in CI.
