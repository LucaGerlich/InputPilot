import SwiftUI

/// The menu bar menu, task first: which keyboard is in use and what it maps
/// to, then switching controls. Hardware details live under Diagnostics.
struct MenuBarMenuView: View {
    let updaterService: UpdaterService

    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        if !appState.isInputMonitoringGranted {
            permissionSection
            Divider()
        }

        keyboardSection

        Divider()

        autoSwitchSection

        if appState.hasMappingConflicts {
            Divider()

            Label(
                "\(appState.mappingConflicts.count) mapping(s) point to a removed input source",
                systemImage: "exclamationmark.triangle.fill"
            )
            Button("Fix in Settings…") {
                open("settings")
            }
        }

        Divider()

        Button {
            open("settings")
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button {
            updaterService.checkForUpdates()
        } label: {
            Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
        }

        Menu("Diagnostics") {
            diagnostics
        }

        Divider()

        Button("Quit InputPilot") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    @ViewBuilder
    private var permissionSection: some View {
        Label(
            appState.status.permissionStatus == .denied
                ? "Input Monitoring is switched off for InputPilot"
                : "InputPilot needs Input Monitoring",
            systemImage: "exclamationmark.triangle.fill"
        )

        // macOS prompts only once; after a denial only System Settings helps.
        if appState.status.permissionStatus == .unknown {
            Button("Grant Access…") {
                appState.requestInputMonitoringPermission()
            }
        }

        Button("Open Input Monitoring Settings…") {
            appState.openInputMonitoringSettings()
        }
    }

    @ViewBuilder
    private var keyboardSection: some View {
        if let keyboard = appState.activeKeyboardTitle {
            Text("Typing on \(keyboard) → \(appState.activeKeyboardTargetName ?? "not mapped")")

            if let hold = appState.manualHoldDescription {
                Text(hold)
            }

            if appState.canUseCurrentSourceForActiveDevice, let source = appState.currentInputSourceName {
                Button("Use \(source) for \(keyboard)") {
                    appState.useCurrentInputSourceForActiveDevice()
                }
            }
        } else if appState.isInputMonitoringGranted, appState.isKeyboardMonitorRunning {
            Text("Press any key to detect your keyboard")
        }

        if appState.isInputMonitoringGranted, !appState.isKeyboardMonitorRunning {
            Text("Keyboard detection isn't running")
            relaunchButton
        } else if appState.monitorHasPartialAccess {
            Text("A keyboard is held by another app – see Settings")
            relaunchButton
        }
    }

    @ViewBuilder
    private var autoSwitchSection: some View {
        Toggle(
            "Automatic Switching",
            isOn: Binding(
                get: { appState.autoSwitchEnabled },
                set: { appState.setAutoSwitchEnabled($0) }
            )
        )

        if let reason = appState.autoSwitchOffReason {
            Text(reason)
        }

        if appState.isAutoSwitchPaused, let pauseUntil = appState.pauseUntil {
            Text(appState.pausedUntilText(pauseUntil))

            Button("Resume") {
                appState.resume()
            }
        } else {
            Button("Pause for 15 Minutes") {
                appState.pause(minutes: 15)
            }
            .disabled(!appState.autoSwitchEnabled)

            Button("Pause for 1 Hour") {
                appState.pause(minutes: 60)
            }
            .disabled(!appState.autoSwitchEnabled)
        }

        if appState.canUndoLastSwitch, let lastAction = appState.lastAction {
            let target = appState.inputSourceName(for: lastAction.toInputSourceId)
            let time = Self.timeFormatter.string(from: lastAction.timestamp)
            Button("Undo Switch to \(target) (\(lastAction.deviceDisplayName), \(time))") {
                appState.undoLastSwitch()
            }
        }

        // Monitor failures have their own line above; this is for switch errors.
        if appState.isKeyboardMonitorRunning, let error = appState.lastAutoSwitchError {
            Text("Error: \(error)")
        }
    }

    @ViewBuilder
    private var diagnostics: some View {
        Text(appState.permissionLine)
        Text(appState.monitorLine)
        Text(appState.activeInputSourceLine)
        Text("Input source ID: \(appState.currentInputSourceId ?? "none")")

        if let keyboard = appState.activeKeyboardDevice {
            Text("Keyboard: \(keyboard.displayName)")
            Text("Vendor \(KeyboardFingerprint.hardwareIdLabel(keyboard.vendorId)) · Product \(KeyboardFingerprint.hardwareIdLabel(keyboard.productId))")
            Text("Connection: \(keyboard.transport ?? "unknown") · Location \(keyboard.locationId.map(String.init) ?? "unknown")")
        }

        Text("Last action: \(appState.lastAutoSwitchAction)")

        Divider()

        Button("Open Debug Log…") {
            open("debug-log")
        }

#if DEBUG
        Divider()

        ForEach(appState.enabledInputSources) { source in
            Button {
                appState.selectInputSource(source.id)
            } label: {
                if source.id == appState.currentInputSourceId {
                    Label(source.name, systemImage: "checkmark")
                } else {
                    Text(source.name)
                }
            }
            .disabled(!source.isSelectable)
        }
#endif
    }

    private var relaunchButton: some View {
        Button("Relaunch InputPilot") {
            appState.relaunch()
        }
    }

    private func open(_ windowId: String) {
        openWindow(id: windowId)
        // A menu bar app is never frontmost on its own. Without this the window
        // can open behind the active app, with no Dock icon or ⌘-Tab to reach it.
        NSApp.activate(ignoringOtherApps: true)
    }
}
