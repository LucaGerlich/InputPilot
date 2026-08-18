# Security and Privacy

InputPilot asks for Input Monitoring, the permission that lets an app see keyboard events. That is a lot of trust to ask for, so here is exactly what the app does with it.

## What InputPilot reads

To decide which input source to activate, InputPilot needs to know **which keyboard** produced the most recent key press. Its HID callback takes two things from each event:

- the device that sent it (vendor ID, product ID, transport, product name, location)
- whether the key was a modifier

Nothing else leaves that callback. The key's usage code is read inside it, solely to decide whether the key was a modifier, and is discarded when the callback returns — it is never assigned, stored, logged or transmitted, and no character or typed text is derived from it anywhere in the app.

## What InputPilot stores

Settings and keyboard mappings live in `UserDefaults`: which input source belongs to which keyboard, your fallbacks, the pause timestamp, and a schema migration flag. That is all.

The debug log is an in-memory ring buffer of at most 200 entries, holding device identifiers, permission state, input source names, and errors. It is never written to disk unless you explicitly export it, and export runs the text through a redaction pass that strips any field resembling key codes, typed text, characters, or app contents — defence in depth for a log that should never contain them in the first place.

## What leaves your Mac

Update checks against the appcast at `raw.githubusercontent.com`, and the download itself when you accept an update. Nothing else. There is no telemetry, no analytics, and no crash reporter.

Updates are verified twice: an EdDSA signature over the appcast enclosure, and Apple's notarization of the downloaded app.

## Supply chain

One third-party dependency: [Sparkle](https://github.com/sparkle-project/Sparkle), the standard macOS updater, pinned to a major version via Swift Package Manager. Releases are built locally, signed with a Developer ID certificate, and notarized by Apple. Signing keys are never stored in the repository or in CI — the CI workflow builds and tests only, and cannot produce a signed artifact.

## Supported versions

Fixes go into the latest release. Please update before reporting a problem.

## Reporting a vulnerability

Report privately through [GitHub Security Advisories](https://github.com/LucaGerlich/InputPilot/security/advisories/new) rather than a public issue. Please include the version, your macOS version, and how to reproduce the problem. You can expect an initial response within a week.

If you find that InputPilot handles keystroke data in any way this document does not describe, treat it as a security issue and report it that way.
