import SwiftUI

struct MenuBarMenuView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        Section("Profile") {
            ForEach(appState.profiles) { profile in
                Button {
                    appState.setActiveProfile(profile.id)
                } label: {
                    if profile.id == appState.activeProfileId {
                        Label(profile.name, systemImage: "checkmark")
                    } else {
                        Text(profile.name)
                    }
                }
            }
        }

        Divider()

        Section("Auto-Switch") {
            Toggle(
                "Auto-Switch",
                isOn: Binding(
                    get: { appState.autoSwitchEnabled },
                    set: { appState.setAutoSwitchEnabled($0) }
                )
            )

            Toggle(
                "Show notification on switch",
                isOn: Binding(
                    get: { appState.showNotificationOnSwitch },
                    set: { appState.setShowNotificationOnSwitch($0) }
                )
            )

            if let notificationPermissionHint = appState.notificationPermissionHint {
                Text(notificationPermissionHint)
                    .foregroundStyle(.orange)
            }

            Button("Pause 15 min") {
                appState.pause(minutes: 15)
            }
            .disabled(!appState.autoSwitchEnabled)

            Button("Pause 60 min") {
                appState.pause(minutes: 60)
            }
            .disabled(!appState.autoSwitchEnabled)

            if appState.isAutoSwitchPaused {
                Button("Resume") {
                    appState.resume()
                }
            }

            if let pauseUntil = appState.pauseUntil, appState.isAutoSwitchPaused {
                Text("Paused until \(Self.timeFormatter.string(from: pauseUntil))")
                    .foregroundStyle(.secondary)
            }

            Text("Last action: \(appState.lastAutoSwitchAction)")

            if let error = appState.lastAutoSwitchError {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
            }
        }

        if appState.hasMappingConflicts {
            Divider()

            Section("Warnings") {
                Label(
                    "\(appState.mappingConflicts.count) mapping conflict(s): source missing or disabled",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)

                SettingsLink {
                    Text("Fix in Settings...")
                }
            }
        }

        Divider()

        Section("Last switch") {
            if let lastAction = appState.lastAction {
                let targetName = appState.inputSourceName(for: lastAction.toInputSourceId)
                Text("\(lastAction.deviceDisplayName) → \(targetName) (\(Self.timeFormatter.string(from: lastAction.timestamp)))")

                if appState.canUndoLastSwitch {
                    Button("Undo") {
                        appState.undoLastSwitch()
                    }
                }
            } else {
                Text("No switch action yet.")
                    .foregroundStyle(.secondary)
            }
        }

        Divider()

        if !appState.isInputMonitoringGranted {
            Section("Permission Required") {
                Label(appState.permissionWarningMessage, systemImage: "exclamationmark.triangle.fill")

                Button("Request Permission") {
                    appState.requestInputMonitoringPermission()
                }

                Button("Open Input Monitoring Settings") {
                    appState.openInputMonitoringSettings()
                }
            }

            Divider()
        }

        Section("Status") {
            Text("Profile: \(appState.activeProfileName)")
            Text(appState.permissionLine)
            Text(appState.monitorLine)
            Text(appState.activeKeyboardLine)
            Text(appState.activeInputSourceLine)

            Button("Open Debug") {
                openWindow(id: "debug-log")
            }
        }

        Section("Active Keyboard Device") {
            if let keyboard = appState.activeKeyboardDevice {
                Text("Vendor ID: \(keyboard.vendorId)")
                Text("Product ID: \(keyboard.productId)")
                Text("Product: \(keyboard.productName ?? "unknown")")
                Text("Transport: \(keyboard.transport ?? "unknown")")
                Text("Location ID: \(keyboard.locationId.map(String.init) ?? "unknown")")

                if let temporaryOverride = appState.activeTemporaryOverride {
                    let sourceName = appState.inputSourceName(for: temporaryOverride.inputSourceId)
                    if let expiresAt = temporaryOverride.expiresAt {
                        Text("Lock: \(sourceName) until \(Self.timeFormatter.string(from: expiresAt))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Lock: \(sourceName) until restart")
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Lock current source for this keyboard (until restart)") {
                    appState.lockCurrentInputSourceForActiveKeyboardUntilRestart()
                }
                .disabled(appState.currentInputSourceId == nil)

                Button("Lock until today 23:59") {
                    appState.lockCurrentInputSourceForActiveKeyboardUntilEndOfDay()
                }
                .disabled(appState.currentInputSourceId == nil)

                Button("Clear lock") {
                    appState.clearTemporaryOverrideForActiveKeyboard()
                }
                .disabled(!appState.hasActiveTemporaryOverride)
            } else {
                Text("No active keyboard detected.")
            }

            if let hint = appState.keyboardMonitorHint {
                Text(hint)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Input Sources") {
            Text("Current: \(appState.currentInputSourceName ?? "none")")
            Text("ID: \(appState.currentInputSourceId ?? "none")")

#if DEBUG
            if appState.enabledInputSources.isEmpty {
                Text("No enabled input sources found.")
                    .foregroundStyle(.secondary)
            }

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

        Divider()

        Button("Quit InputPilot") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")

        Divider()

        SettingsLink {
            Label("Settings…", systemImage: "gearshape")
        }
    }
}
