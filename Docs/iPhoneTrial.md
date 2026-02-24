# iPhone Trial Guide

## Preconditions

- Xcode is installed at `/Applications/Xcode.app`.
- iPhone is connected via USB (or trusted wireless pairing).
- iPhone has **Developer Mode** enabled.
- Device trust prompts have been accepted on both Mac and iPhone.
- A valid Apple signing team is available in Xcode (Team ID required).

## 1) Verify local toolchain

```bash
cd /Users/shiwen/Desktop/Todo_lite/Solituder
source scripts/dev-env.sh
make verify-toolchain
```

## 2) List physical devices

```bash
make iphone-list-devices
```

Use the `Identifier` value as `DEVICE_UDID`.

## 3) Install and launch on iPhone

```bash
make iphone-install TEAM_ID=YOUR_TEAM_ID DEVICE_UDID=YOUR_DEVICE_UDID BUNDLE_ID=com.solituder.app.dev
```

What this command does:
- Builds `SolituderApp` for iPhone (`iphoneos`) using automatic signing.
- Installs the generated `.app` via `devicectl`.
- Launches the app on your phone.

## 4) First-run validation on phone

- Permission onboarding page appears.
- Microphone/speech/notifications can be requested.
- Key management page stores OpenAI and ElevenLabs keys.
- After saving keys, standby page can arm/disarm and send prompt.

## Troubleshooting

- `No devices found`:
  - Reconnect cable, unlock iPhone, accept trust prompt.
  - Retry `make iphone-list-devices`.
- `TEAM_ID is required`:
  - Provide `TEAM_ID` in command.
- Signing/provisioning failure:
  - Open `Apps/SolituderApp/SolituderApp.xcodeproj` once in Xcode.
  - Select your Apple team and retry command.
