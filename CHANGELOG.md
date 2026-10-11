# Changelog

All notable changes to InputPilot are documented here. This project follows [Semantic Versioning](https://semver.org).

## [1.1.0] — 2026-10-11

### Added

- **Your own layout choices are respected.** A layout picked by hand — ⌃Space, the input menu, Undo, an input method's mode key — used to be reverted on the next key press. InputPilot now keeps it until you type on another keyboard. Settings → Switching offers three alternatives: keep it until you switch back yourself, switch back on the next key press (the old behaviour), or turn automatic switching off.
- **Open at login.** Offered, pre-checked, at the end of the first run, and as a switch in Settings. Without it, InputPilot stopped working after every restart.
- **A first run that ends somewhere.** The welcome window stays until its last step is done. After the grant macOS needs a fresh start, so the window offers **Relaunch InputPilot** instead of just quitting; after a denial its main button opens System Settings, since macOS only prompts once.
- **"Use … for …" in the menu** maps the keyboard you are typing on to the current input source in one click.
- **Check for updates automatically** can now be switched off in Settings.

### Changed

- The menu leads with what you are typing on and what it maps to. Hardware details and the debug log moved into a Diagnostics submenu, and Settings opens with your keyboards.
- Status and device details use plain words ("Input Monitoring: not granted yet", "USB · Vendor 1452 · Product 832") instead of jargon.
- The Settings "Pause" switch, which paused for a year, is now a plain "Automatic switching" switch. Pausing for 15 minutes or an hour stays in the menu.

### Fixed

- **Two keyboards of the same model** shared one mapping. Each now gets its own, and one of them can still change ports without becoming a third entry.
- **Karabiner-Elements** holding a keyboard stopped keyboard detection outright, with advice to relaunch that could never help. InputPilot now keeps running instead of giving up, and explains how to release that keyboard in Karabiner-Elements.
- Emoji & Symbols, Dictation and Press and Hold were offered as mapping targets; mapped, they opened a panel on every switch. Only keyboard input sources are offered now.
- Windows opened from the menu could appear behind the active app, unreachable without a Dock icon. They now come to the front.
- A lone F6 press was treated as a modifier key and never triggered a switch. HID usage 0x3F is F6; it had been mistaken for Fn.
- While keyboard detection could not start, the same error was added to the debug log every second until it crowded out everything else. Each distinct failure is now logged once.
- Public claims made precisely true: the app reads a key's usage code only to detect modifiers; update checks run automatically once a day; and the Tab in ⌘-Tab counts as typing.

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
- Optional switching on modifier-only key presses, off by default, so a lone ⇧ or ⌘ press does not change the layout. Any other key — including the Tab in ⌘-Tab — counts as typing on that keyboard.
- In-app debug log with copy and export, containing device and status information only.
- Automatic updates via Sparkle; every update archive is EdDSA-signed and verified before install.

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
