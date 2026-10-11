# InputPilot

[![Latest release](https://img.shields.io/github/v/release/LucaGerlich/InputPilot?label=download)](https://github.com/LucaGerlich/InputPilot/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black)](https://github.com/LucaGerlich/InputPilot/releases/latest)
[![CI](https://github.com/LucaGerlich/InputPilot/actions/workflows/ci.yml/badge.svg)](https://github.com/LucaGerlich/InputPilot/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

**Type on the right keyboard, get the right language.** InputPilot is a small macOS menu bar app that notices which keyboard you are typing on and switches the input source to match.

If you keep a German external keyboard next to a US MacBook keyboard, you already know the problem: every switch between them means fixing the layout by hand. Map each keyboard once and InputPilot does it for you.

## Install

With [Homebrew](https://brew.sh):

```bash
brew tap LucaGerlich/tap
brew install --cask inputpilot
```

Or manually:

1. Download **`InputPilot-x.y.z.dmg`** from the [latest release](https://github.com/LucaGerlich/InputPilot/releases/latest).
2. Open the DMG and drag InputPilot into Applications.

Then, either way:

3. Launch it. A keyboard icon appears in the menu bar — there is no Dock icon and no main window.
4. A welcome window asks for **Input Monitoring**. Grant it, then quit and reopen InputPilot if macOS asks.
5. Press a key on each keyboard you want to configure, then open **Settings** from the menu bar icon and pick an input source per keyboard.

The app is signed with a Developer ID certificate and notarized by Apple, so it opens without Gatekeeper warnings. It updates itself through [Sparkle](https://sparkle-project.org); you can also check manually from the menu bar.

> **If InputPilot does not appear under Input Monitoring** after you allow the prompt, add it by hand: System Settings → Privacy & Security → Input Monitoring → **+** → pick InputPilot in Applications, then switch it on. Some Macs do not populate that list on their own.

## Why it needs Input Monitoring

To tell your keyboards apart, InputPilot has to see that *a* key was pressed and on *which* device. macOS puts that behind the Input Monitoring permission.

It never records what you type. The HID callback keeps exactly two things — the device that sent the event, and whether the key was a modifier. The key's usage code is read only to compute that second value and is then discarded: it is never stored, logged or transmitted, and no character or text is derived from it. Nothing you type is sent off your Mac: the only network traffic is Sparkle's update check (automatically once a day, or when you choose Check for Updates) and the download of any update you accept. Sparkle is the only third-party dependency.

See [SECURITY.md](SECURITY.md) for the full privacy statement and how to report a vulnerability.

## Features

- **Per-keyboard input sources** — map each keyboard to the layout you want, from Settings or with one click on "Use … for …" in the menu.
- **Respects your own choices** — pick a layout by hand (⌃Space, the input menu, Undo) and InputPilot keeps it until you switch keyboards. Settings offers three alternatives: keep it until you switch back yourself, switch back on the next key press, or turn automatic switching off.
- **Opens at login** — offered, pre-checked, at the end of the first run, and in Settings.
- **Fallbacks** — a per-device fallback for when a mapping breaks, and a global fallback for unmapped keyboards.
- **Undo** — revert the last automatic switch from the menu.
- **Pause** — silence auto-switching for 15 minutes or an hour when it would get in the way.
- **Conflict detection** — spots mappings that point at an input source you have since removed or disabled, and offers to fix them.
- **Stable device identity** — keyboards are matched on vendor, product, transport and name, so unplugging and replugging (or moving to another USB port) keeps your mapping — and two USB keyboards of the same model, on different ports, each get their own.
- **No flapping** — a 400 ms debounce and a 1.5 s cooldown stop rapid switching, and a lone modifier press (⇧, ⌘, ⌥ or ⌃ on its own) is ignored by default. Any other key — including the Tab in ⌘-Tab — counts as typing on that keyboard.
- **Debug log** — an in-app log window you can copy or export when reporting a bug. It contains device and status information only, never typed text.

## How it works

1. A HID callback reports which keyboard produced the latest key press.
2. InputPilot resolves the target input source for that device, in order: **device mapping → per-device fallback → global fallback**. If none apply, it does nothing.
3. After the debounce settles, it switches the input source through the Text Input Sources (TIS) API.
4. It remembers the source it applied. If the current source differs at the next switch, someone else chose it, and your manual-change setting decides what happens.

Auto-switching only runs when it is enabled and not paused.

## Settings

| Section | What it does |
|---|---|
| Needs Attention | Only shown when a mapping points at a removed or disabled source, with a fix action |
| Keyboards | Per-keyboard input source, per-keyboard fallback, forget a keyboard |
| Switching | Automatic switching on/off, Open at login, what happens when you change the source yourself, modifier-only switching |
| Fallbacks | The input source for every keyboard without one of its own |
| Updates | Sparkle's automatic daily check on/off, and Check Now |
| Status | Permission, keyboard detection, current keyboard and source, last action and error |

## Troubleshooting

**Nothing switches.** Open the menu bar menu: it shows which keyboard you are typing on, what it maps to, and whether InputPilot is keeping a layout you chose yourself. Diagnostics shows the permission and keyboard detection. Auto-switch must be enabled and not paused, and the target input source must still be enabled in System Settings → Keyboard → Input Sources.

**Permission granted but nothing happens.** macOS applies Input Monitoring only to a fresh start. Click **Relaunch InputPilot** in the welcome window or in Settings → Status.

**My layout changes back / does not change back.** That is the manual-change setting in Settings → Switching. By default a layout you pick yourself is kept until you type on another keyboard. macOS's own "Automatically switch to a document's input source" also counts as a change you made.

**Karabiner-Elements.** For every keyboard whose events Karabiner-Elements modifies, it takes exclusive access and re-sends the keys from its own virtual keyboard, so InputPilot cannot see which physical keyboard you used. In Karabiner-Elements → Devices, turn off "Modify events" for each keyboard InputPilot should tell apart, then relaunch InputPilot.

**A keyboard is not detected.** Press a key on it — mouse movement is not enough. InputPilot only learns about a keyboard once it produces a key event.

**It switches too eagerly.** Turn off "Switch on modifier-only key presses" in Settings if you turned it on. For unusual setups such as a KVM, give each device an explicit mapping or fallback.

**Reporting a bug.** Open the debug log from the menu bar, reproduce the problem, export the log, and attach it to a [new issue](https://github.com/LucaGerlich/InputPilot/issues/new/choose). The log is safe to share.

## What it stores

Settings live in `UserDefaults`: the auto-switch and modifier-only flags, the manual-change setting, the pause timestamp, the global fallback, your device mappings, whether the first run is finished, and a schema migration flag. Open at login is registered with macOS itself (System Settings → General → Login Items). The last switch and the debug log are in memory only and disappear when you quit. If stored mappings ever fail to decode, the raw data is preserved under a `.corrupted` key rather than being overwritten.

## Requirements

macOS 13.0 (Ventura) or newer, Apple silicon or Intel.

---

## Development

Building from source needs **Xcode 26** or newer (the project uses the Xcode 16+ project format and a Swift 6.2 toolchain).

```bash
git clone https://github.com/LucaGerlich/InputPilot.git
cd InputPilot
xcodebuild -scheme InputPilot -destination 'platform=macOS' build
xcodebuild -scheme InputPilot -destination 'platform=macOS' test
```

Open `InputPilot.xcodeproj` and press ⌘R to run. Note that an app launched from Xcode runs under the debugger, and macOS attributes Input Monitoring to Xcode rather than to the app — to test the permission flow, run a built copy from Finder instead.

### Architecture

`AppState` is the orchestrator: it owns the published UI state and makes every switch decision. Everything it touches sits behind a protocol (`PermissionServicing`, `HIDKeyboardMonitoring`, `InputSourceServicing`, `MappingStoring`, `ClockProviding`, `DebugLogServicing`), so the logic is testable without HID hardware or a real input source. `SwitchController` isolates debounce and cooldown behind an injectable clock. Persistence is deliberately plain `UserDefaults` behind small stores.

```text
InputPilot/
  App/          AppState (orchestration), InputPilotApp (scenes)
  Services/     HID monitoring, input sources, permissions, updates, logging
  Models/       Device identity, fingerprints, events, snapshots
  Persistence/  Mapping and settings stores
  UI/           Menu bar, settings, welcome, debug log
Scripts/        release.sh, ExportOptions.plist
Config/         AppInfo.plist (privacy strings, Sparkle feed)
docs/           Engineering notes
```

### Tests

Swift Testing (`import Testing`). Covered: auto-switch behaviour including pause, resume and undo; failure paths such as denied or revoked permission, a HID monitor that will not start, and a failing input-source switch; debounce and cooldown under a controlled clock; mapping persistence, migration and corrupt-data recovery; and the debug log's ring buffer and redaction.

### Releasing

Maintainers only; needs a Developer ID certificate, notarytool credentials, and the Sparkle signing key.

```bash
Scripts/release.sh 1.0.2
```

The script verifies versions, archives, exports with Developer ID, notarizes and staples both the app and the DMG, checks Gatekeeper, and generates the appcast. It then prints the remaining steps: tag, publish the release with the DMG attached, and commit the updated `appcast.xml`.

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Changes to the release pipeline or the permission flow should say how they were verified, since neither is covered by automated tests.

## License

[Apache License 2.0](LICENSE) © 2026 Luca Gerlich
