import SwiftUI

struct SettingsView: View {
    private let noAutoSwitchTag = "__NO_AUTO_SWITCH__"

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
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

            Section("Input Monitoring") {
                Text(appState.permissionLine)
                Text(appState.activeKeyboardLine)
                Text(appState.activeInputSourceLine)
            }

            Section("Input Sources") {
                Text("Current: \(appState.currentInputSourceName ?? "none")")
                Text("ID: \(appState.currentInputSourceId ?? "none")")
            }

            Section("Keyboard Device Mappings") {
                if appState.knownDeviceKeys.isEmpty {
                    Text("No keyboard devices recognized yet. Press a key on a keyboard to detect it.")
                        .foregroundStyle(.secondary)
                }

                ForEach(appState.knownDeviceKeys, id: \.self) { deviceKey in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.deviceTitle(for: deviceKey))
                            .font(.headline)

                        Text(appState.deviceSubtitle(for: deviceKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if appState.selectableInputSources.isEmpty {
                            Text("No selectable input sources available.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Input Source", selection: mappingSelectionBinding(for: deviceKey)) {
                                Text("No automatic switch")
                                    .tag(noAutoSwitchTag)

                                ForEach(appState.selectableInputSources) { inputSource in
                                    Text(inputSource.name)
                                        .tag(inputSource.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Button("Forget device", role: .destructive) {
                            appState.forgetDevice(deviceKey)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
    }

    private func mappingSelectionBinding(for deviceKey: KeyboardDeviceKey) -> Binding<String> {
        Binding(
            get: {
                appState.mappedInputSourceId(for: deviceKey) ?? noAutoSwitchTag
            },
            set: { selection in
                if selection == noAutoSwitchTag {
                    appState.setMapping(for: deviceKey, inputSourceId: nil)
                } else {
                    appState.setMapping(for: deviceKey, inputSourceId: selection)
                }
            }
        )
    }
}
