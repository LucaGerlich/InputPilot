# Changelog

All notable changes to InputPilot are documented here. This project follows [Semantic Versioning](https://semver.org).

## [1.0.1] — 2026-08-18

### Fixed

- **First launch now asks for Input Monitoring.** 1.0.0 only *checked* the permission and never requested it, so a new user saw nothing at all: no prompt, no window, and — because macOS does not list an app that has never requested access — no way to grant it by hand either. A welcome window now explains what InputPilot does, why the permission is needed, and that it never reads typed text, with a button that triggers the system prompt.
- The welcome window also covers the state right after a grant, where macOS reports the permission as granted but only applies it on the next launch, by offering to quit and reopen instead of leaving the app looking permitted but inert.
- "Fix in Settings…" in the conflict warning did nothing. It used `SettingsLink`, which targets a `Settings` scene the app does not declare.

### Changed

- The release pipeline now derives versions from the project file and refuses to build when the marketing version does not match the requested release, or when the build number is not greater than the one the published appcast advertises. Sparkle compares build numbers, so the previous behaviour could have shipped an update that was never offered.

## [1.0.0] — 2026-08-18

First public release.

### Added

- Per-keyboard input source mapping, with per-device and global fallbacks.
- Undo for the last automatic switch, and pause for 15 or 60 minutes.
- Conflict detection for mappings pointing at removed or disabled input sources.
- Debounce (400 ms) and cooldown (1.5 s) to prevent flapping between keyboards.
- Optional switching on modifier-only key presses, off by default, so ⌘-Tab does not change the layout.
- In-app debug log with copy and export, containing device and status information only.
- Automatic updates via Sparkle, over a signed appcast.

### Fixed

Issues found in the pre-release audit and fixed before shipping:

- Switch decisions and undo read the current input source fresh instead of a cache that could be six seconds stale, so an input source changed outside the app no longer suppresses a switch or corrupts what undo restores.
- Undecodable mapping data is preserved under a `.corrupted` backup key and logged, instead of being silently replaced on the next write — previously one decode failure could destroy every stored mapping.
- Keyboards without vendor or product IDs are no longer treated as one shared device.
- Unplugging the active keyboard now clears it from the display.

### Security

- Signed with a Developer ID certificate and notarized by Apple; both the app and the DMG carry a stapled notarization ticket, so first launch works offline.

[1.0.1]: https://github.com/LucaGerlich/InputPilot/releases/tag/v1.0.1
[1.0.0]: https://github.com/LucaGerlich/InputPilot/releases/tag/v1.0.0
