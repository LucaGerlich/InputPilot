# Security and Privacy

InputPilot asks for Input Monitoring, the permission that lets an app see keyboard events. That is a lot of trust to ask for, so here is exactly what the app does with it.

## What InputPilot reads

To decide which input source to activate, InputPilot needs to know **which keyboard** produced the most recent key press. Its HID callback takes two things from each event:

- the device that sent it (vendor ID, product ID, transport, product name, location)
- whether the key was a modifier

Nothing else leaves that callback. The key's usage code is read inside it, solely to decide whether the key was a modifier. It exists only as a local constant within the callback and is gone when the callback returns — it is never kept in a property, stored, logged or transmitted, and no character or typed text is derived from it anywhere in the app.

## What InputPilot stores

Settings and keyboard mappings live in `UserDefaults` (`com.lucagerlich.InputPilot`):

- for each keyboard you have used: its identifiers (vendor ID, product ID, transport, product name, location) and the input source mapped to it
- your fallbacks, the auto-switch and modifier-only settings, and the pause timestamp
- a schema migration flag
- only if stored mappings ever fail to decode: a `.corrupted` backup of that data, so it is not lost

Sparkle keeps its own bookkeeping in the same place: when it last checked for updates, whether the app has launched before, and a random number it uses for staged rollouts. No key or typing data is stored anywhere.

The debug log is an in-memory ring buffer of at most 200 entries, holding device identifiers, permission state, input source names, and errors. It is never written to disk unless you explicitly export it, and only reaches the clipboard if you copy it. As each entry is recorded, a filter replaces the words `keycode`, `typedtext`, `characters`, `appcontents` and `keystroke` with `[redacted]`. That filter is a tripwire, not the guarantee — the guarantee is that no code path sends key data to the log in the first place.

## What leaves your Mac

Update checks against the appcast at `raw.githubusercontent.com` — automatically about once a day, and whenever you choose Check for Updates — and the download itself when you accept an update. Each check is an ordinary HTTPS request, so GitHub sees your IP address and a user agent naming the app and Sparkle versions. Nothing else is sent. There is no telemetry, no analytics, and no crash reporter.

Sparkle verifies every update before installing it: an EdDSA signature over the downloaded archive, checked against the public key built into the app, and a code-signature check that the new app is signed by the same Developer ID team. Each release is also notarized by Apple.

## Supply chain

One third-party dependency: [Sparkle](https://github.com/sparkle-project/Sparkle), the standard macOS updater, pinned to a major version via Swift Package Manager. Releases are built locally, signed with a Developer ID certificate, and notarized by Apple. Signing keys are never stored in the repository or in CI — the CI workflow builds and tests only, and cannot produce a signed artifact.

## Supported versions

Fixes go into the latest release. Please update before reporting a problem.

## Reporting a vulnerability

Report privately through [GitHub Security Advisories](https://github.com/LucaGerlich/InputPilot/security/advisories/new) rather than a public issue. Please include the version, your macOS version, and how to reproduce the problem. You can expect an initial response within a week.

If you find that InputPilot handles keystroke data in any way this document does not describe, treat it as a security issue and report it that way.
