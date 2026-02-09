# InputPilot

InputPilot is a macOS menu bar app built with Swift/SwiftUI that detects the active keyboard and automatically switches to the matching input source (keyboard layout).

This README reflects the current state of the `main` branch.

## Table of Contents

- [What InputPilot Does](#what-inputpilot-does)
- [Core Features](#core-features)
- [Privacy and Security](#privacy-and-security)
- [Requirements](#requirements)
- [Build and Run](#build-and-run)
- [How to Use](#how-to-use)
- [Auto-Switch Logic (Important)](#auto-switch-logic-important)
- [Persisted Data](#persisted-data)
- [Debugging](#debugging)
- [Tests](#tests)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [Known Limitations](#known-limitations)

## What InputPilot Does

Typical use case: you use multiple keyboards (for example an internal MacBook keyboard and an external keyboard), and you want the input source to follow the keyboard you are actively using.

InputPilot does this by:

1. Detecting the keyboard that produced the latest key event via HID.
2. Looking up the configured input source for that device.
3. Switching input source using Carbon/TIS.

## Core Features

- MenuBarExtra UI with live status.
- Input Monitoring permission flow:
  - check status
  - request permission
  - open System Settings directly
- HID keyboard monitoring:
  - start/stop with error handling
  - keyDown detection without logging typed characters
  - modifier-only handling for anti-flapping behavior
- Input source service (Carbon TIS):
  - list enabled/all sources
  - read current source
  - select source by ID
- Per-device mappings.
- Per-device fallback input source.
- Global fallback input source.
- Undo for the last auto-switch action.
- Debounce + cooldown via `SwitchController`.
- Conflict detection:
  - detects mappings that target missing/disabled sources
  - surfaces conflicts in menu and settings
- Debug window with ring-buffer logs:
  - live view
  - copy to clipboard
  - export as `.txt`
- Quit action directly in the menu.
- No external dependencies.

## Privacy and Security

- No keylogging.
- No typed text is stored.
- No keycodes or app content are stored.
- HID events are only used for device/event classification and switching logic.
- Debug logs contain technical status/error information only.
- Exported logs are sanitized (sensitive tokens are redacted).

## Requirements

- macOS (current project deployment target: `15.7`)
- Xcode 15+
- Swift 5

## Build and Run

1. Open the project:
   - `InputPilot.xcodeproj`
2. Select the `InputPilot` scheme.
3. Run the app.
4. Grant Input Monitoring permission when prompted.

CLI build:

```bash
xcodebuild -scheme InputPilot -destination 'platform=macOS' build
```

## How to Use

### Initial Setup

1. Launch the app (keyboard icon in the menu bar).
2. If permission is missing in the menu:
   - click `Request Permission`
   - if needed, click `Open Input Monitoring Settings`
3. Press at least one key on each keyboard you want to configure so the device is detected.
4. Open `Settings…` and configure a mapping for each device.

### Key Menu Actions

- `Auto-Switch` on/off
- `Pause 15 min` / `Pause 60 min` / `Resume`
- `Last switch` + `Undo`
- `Open Debug`
- `Quit InputPilot`

### Settings Overview

- `Auto-Switch`: pause state, last action, latest error
- `Input Monitoring`: permission and active device/source status
- `Input Sources`: current source and ID
- `Fallbacks`: global fallback and quick action to use current source
- `Conflicts`: invalid mappings with `Fix...` action
- `Keyboard Device Mappings`: mapping, per-device fallback, forget device

## Auto-Switch Logic (Important)

### Target Source Resolution Order

1. Device mapping
2. Per-device fallback
3. Global fallback
4. Otherwise no action

Auto-switch is active only when `isAutoSwitchActive == true`:

- `autoSwitchEnabled == true`
- not paused (`pauseUntil` is `nil` or in the past)

### Stabilization Against Flapping

- Debounce: `400ms` (default)
- Cooldown after successful switch: `1500ms`
- Modifier-only keyDown events do not trigger aggressive switching; switching waits for a stable trigger.

### Fingerprint and Matching

- Primary match key: `vendorId + productId + transport + isBuiltIn (+ normalized productName)`
- `locationId` is used as a hint/tie-breaker
- Goal: stable behavior across port changes and varying HID metadata

## Persisted Data

InputPilot stores the following in `UserDefaults`:

- auto-switch enabled flag
- pause-until timestamp
- global fallback input source ID
- device mappings (including per-device fallback)
- migration flag for mapping schema (legacy -> v2)

Not persisted:

- `lastAction` (runtime only)
- debug log ring buffer (runtime only)

## Debugging

`Open Debug` in the menu opens a dedicated window with:

- log list (newest first)
- level (`INFO`, `WARN`, `ERROR`)
- category and timestamp
- `Copy to Clipboard`
- `Export…`

Recommended issue workflow:

1. Open Debug window.
2. Reproduce the issue.
3. Export logs.
4. Inspect relevant error lines.

## Tests

Test framework: Swift Testing (`import Testing`)

Covered areas:

- `AppState` auto-switch behavior including pause/resume/undo
- `SwitchController` debounce/cooldown behavior
- `MappingStore` roundtrip, conflicts, migration
- `DebugLogService` ring buffer and privacy sanitization

Run tests:

```bash
xcodebuild -scheme InputPilot -destination 'platform=macOS' test
```

## Project Structure

```text
InputPilot/
  App/
    AppState.swift
    InputPilotApp.swift
  Services/
    PermissionService.swift
    HIDKeyboardMonitor.swift
    InputSourceService.swift
    SwitchController.swift
    DebugLogService.swift
    ServiceProtocols.swift
  Models/
    ActiveKeyboardDevice.swift
    KeyboardFingerprint.swift
    KeyboardDeviceKey.swift
    KeyboardEventKind.swift
    InputSourceInfo.swift
    InputStatusSnapshot.swift
    MappingConflict.swift
    SwitchAction.swift
  Persistence/
    MappingStore.swift
    AppSettingsStore.swift
  UI/
    MenuBarMenuView.swift
    SettingsView.swift
    DebugLogView.swift
```

## Architecture

- `AppState` is the central orchestrator (UI state + switch decisions).
- Services are abstracted behind protocols (`PermissionServicing`, `HIDKeyboardMonitoring`, `InputSourceServicing`, `MappingStoring`, `ClockProviding`, `DebugLogServicing`).
- `SwitchController` encapsulates debounce/cooldown independent of UI.
- Persistence is intentionally lightweight (`UserDefaults` via stores).

## Troubleshooting

### "Permission granted, but monitor does not start"

- Verify Input Monitoring permission in macOS Privacy settings.
- Restart the app.
- Check logs for `kIOReturnNotPermitted` or `kIOReturnNotPrivileged`.

### No devices are detected

- Confirm Input Monitoring is actually `granted`.
- Press a key on the target keyboard (mouse movement is not enough).
- Check `Status` and `Active Keyboard Device` in the menu.

### Input source is not switching

- Verify the device mapping in Settings.
- Ensure the target source is enabled and selectable.
- Check `Conflicts` for `missing/disabled`.
- Verify pause state and `Auto-Switch` toggle.

### Too many switches

- Debounce/cooldown is active; inspect logs for edge cases.
- For unstable setups (for example KVM), configure explicit mapping/fallback.

## Known Limitations

- macOS only.
- Input Monitoring permission is required.
- Detection depends on keyboard events; no key event means no active-device update.
- No cloud sync/profile/hotkey management in the current `main` branch.
