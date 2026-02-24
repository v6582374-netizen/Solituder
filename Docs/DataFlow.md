# Data Flow

## Foreground armed flow

1. App enters foreground and calls `arm(modelId:)`.
2. `WakeWordEngine` starts local phrase detection.
3. On trigger, orchestrator starts conversation session.
4. `LLMProviderAdapter` connects realtime (OpenAI).
5. Text response is sent to `SpeechOutputAdapter` for voice output.
6. Optional summary is encrypted and stored in `LocalMemoryStore`.

## Background transition flow

1. App lifecycle enters background.
2. Orchestrator calls `transitionToBackground()`.
3. Wake-word listening stops and state becomes `BackgroundSuspended`.
4. Returning foreground can re-arm with prior model via `transitionToForeground()`.

## Data persistence

- Credentials: Keychain only.
- Memory summaries: encrypted local file only.
- Raw audio: not persisted by default.
