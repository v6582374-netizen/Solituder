# App Store Compliance Checklist (MVP)

## Product behavior

- [x] No claim of continuous background microphone listening.
- [x] Background entry explicitly stops wake-word listening.
- [x] Foreground-only wake-word arming is documented.
- [x] Product copy avoids \"always-on background listener\" wording.

## Permissions and privacy

- [ ] Add `NSMicrophoneUsageDescription` with explicit purpose.
- [ ] Add `NSSpeechRecognitionUsageDescription` with explicit purpose.
- [ ] Add in-app privacy controls for clearing local memory.
- [ ] Display visible recording/listening status when microphone is active.

## Security

- [x] API keys stored in Keychain (`ThisDeviceOnly`).
- [x] Log redaction pipeline implemented.
- [x] Runtime risk check hook implemented.

## Release gates

- [ ] Complete MASVS L1 verification.
- [ ] Run network interception test to validate transport security.
- [ ] Validate all third-party SDK privacy manifests before submission.
