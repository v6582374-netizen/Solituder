# Build Validation (2026-02-25)

## Toolchain checks

```bash
make verify-toolchain
```

Observed:
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- `Xcode 26.2 (17C52)`
- Swift 6.2.3

## SPM checks

```bash
make spm-list-tests
make test
```

Result:
- Test discovery lists 11 tests.
- Test run passes (`11/11`).

## App shell build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Apps/SolituderApp/SolituderApp.xcodeproj \
  -scheme SolituderApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Result:
- `** BUILD SUCCEEDED **`
- Screenshot captured: `Docs/simulator-run.png` (app launched on iPhone 17 Pro simulator)

## Manual acceptance checklist

- [ ] First launch opens permission onboarding.
- [ ] Requesting microphone/speech/notification updates state badges.
- [ ] Key screen requires biometric authentication before revealing stored keys.
- [ ] Saving valid OpenAI + ElevenLabs keys routes to standby screen.
- [ ] Arm/disarm toggles orchestrator state in UI.
- [ ] Sending prompt returns text and starts voice playback.
- [ ] Moving app to background transitions to suspended state.
