# InputPilot

InputPilot ist eine macOS-MenuBar-App (SwiftUI), die das aktive Keyboard erkennt und automatisch auf das passende Input Source Layout wechselt.

## Features

- MenuBar-App mit Live-Status (Permission, Monitor, aktives Gerät, aktuelle Input Source)
- Input Monitoring Permission Flow (prüfen, anfragen, Systemeinstellungen öffnen)
- HID Keyboard Monitoring ohne Keylogging
- Auto-Switch mit Debounce/Cooldown gegen Flapping
- Profile/Szenen (mindestens `Default` und `Coding`)
- Mapping pro Gerät und pro Profil
- Fallbacks:
  - pro Gerät
  - global
- Temporäre Device-Locks:
  - bis Neustart
  - bis heute 23:59
- Allow/Deny Device Filter (global)
- Last Switch + Undo
- Optionale Benachrichtigung nach Switch
- Globale Hotkeys (Carbon `RegisterEventHotKey`)
- Debug Overlay mit Ring-Buffer-Log + Export/Copy
- Backup/Import (JSON, `schemaVersion: 1`)
- Optionales iCloud-Drive-Sync für Backup-Datei

## Datenschutz / Privacy

- Es werden keine Tastaturzeichen, Keycodes oder App-Inhalte gespeichert.
- Der Monitor reagiert nur auf relevante HID-Ereignisse zur Geräteerkennung und Switch-Logik.
- Debug-Logs sind auf technische Status-/Fehlerinformationen begrenzt.

## Voraussetzungen

- macOS (Projektziel aktuell: `MACOSX_DEPLOYMENT_TARGET = 15.7`)
- Xcode 15+ (oder aktueller)
- Swift 5

## Build & Run

1. Projekt in Xcode öffnen:
   - `InputPilot.xcodeproj`
2. Scheme `InputPilot` wählen.
3. App starten (`Run`).
4. Beim ersten Start ggf. Input Monitoring Berechtigung erteilen.

## Tests

```bash
xcodebuild -scheme InputPilot -destination 'platform=macOS' test
```

## Nutzung (Kurz)

1. App starten (Keyboard-Icon in der MenuBar).
2. Auf jedem gewünschten Keyboard mindestens eine Taste drücken, damit das Gerät erkannt wird.
3. In `Settings…` pro Gerät ein Input Source Mapping setzen.
4. Optional:
   - Profile wechseln
   - Fallbacks konfigurieren
   - Auto-Switch pausieren
   - Temp-Lock für aktives Gerät setzen
   - Hotkeys konfigurieren
5. Bei Problemen `Open Debug` im Menü verwenden.

## Berechtigungen

- **Input Monitoring**: erforderlich für HID-basierte Erkennung.
- **Notifications**: nur erforderlich, wenn „Show notification on switch“ aktiviert wird.

## Backup / Restore

- Export/Import in den Einstellungen (`Export…` / `Import…`)
- JSON enthält:
  - Profiles
  - Mappings
  - Fallbacks
  - Device Filter
  - relevante Settings
- Debug-Logs sind nicht Teil des Backups.

## Projektstruktur

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
    GlobalHotkeyService.swift
    NotificationService.swift
    DebugLogService.swift
    TemporaryOverrideStore.swift
    ICloudDriveSyncService.swift
    ServiceProtocols.swift
  Models/
    ActiveKeyboardDevice.swift
    KeyboardFingerprint.swift
    KeyboardDeviceKey.swift
    InputSourceInfo.swift
    MappingConflict.swift
    MappingBackupEntry.swift
    AppBackupSnapshot.swift
    Profile.swift
    TemporaryOverride.swift
    DeviceFilterRule.swift
    KeyCombo.swift
    HotkeyAction.swift
    SwitchAction.swift
    InputStatusSnapshot.swift
    KeyboardEventKind.swift
  Persistence/
    MappingStore.swift
    ProfileManager.swift
    AppSettingsStore.swift
  UI/
    MenuBarMenuView.swift
    SettingsView.swift
    DebugLogView.swift
```

## Hinweise

- Input Sources werden über Carbon/TIS gesteuert.
- HID Monitoring und Input Source Switching verwenden ausschließlich macOS-System-APIs (keine externen Dependencies).
