import SwiftUI

struct MenuBarMenuView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Section("Auto-Switch") {
            Toggle(
                "Pause Auto-Switch",
                isOn: Binding(
                    get: { appState.isAutoSwitchPaused },
                    set: { appState.setAutoSwitchPaused($0) }
                )
            )

            Text("Last action: \(appState.lastAutoSwitchAction)")

            if let error = appState.lastAutoSwitchError {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
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
            Text(appState.permissionLine)
            Text(appState.activeKeyboardLine)
            Text(appState.activeInputSourceLine)
        }

        Section("Active Keyboard Device") {
            if let keyboard = appState.activeKeyboardDevice {
                Text("Vendor ID: \(keyboard.vendorId)")
                Text("Product ID: \(keyboard.productId)")
                Text("Product: \(keyboard.productName ?? "unknown")")
                Text("Transport: \(keyboard.transport ?? "unknown")")
                Text("Location ID: \(keyboard.locationId.map(String.init) ?? "unknown")")
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
