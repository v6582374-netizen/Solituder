# Residency Policy (App Store Path)

## Conclusion

For App Store distribution, iOS cannot guarantee third-party apps remain alive indefinitely for continuous background listening.

References:
- App Review Guidelines 2.5.4: https://developer.apple.com/app-store/review/guidelines/
- Apple DTS background execution guidance: https://developer.apple.com/forums/thread/685525

## Product commitment

- Foreground standby is the primary mode.
- Voice listening is active only while the app is foreground and armed.
- When the app transitions to background, listening is suspended within 2 seconds.
- The product must not claim continuous background listening in user-facing copy.

## Implementation guidance

- Use lifecycle wiring to move the agent to `BackgroundSuspended` when scene phase becomes background.
- Resume arming only after scene phase returns to active state.
- Keep a visible microphone/listening status indicator while foreground listening is enabled.

## Out of scope for App Store MVP

- System-level persistent listener behavior.
- Claims of guaranteed always-on background wake-word detection.
