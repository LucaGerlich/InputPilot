import SwiftUI

struct SettingsView: View {
    private let noAutoSwitchTag = "__NO_AUTO_SWITCH__"
    private let noFallbackTag = "__NO_FALLBACK__"

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

            Section("Fallbacks") {
                if appState.selectableInputSources.isEmpty {
                    Text("No selectable input sources available.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Global Fallback", selection: globalFallbackSelectionBinding) {
                        Text("No global fallback")
                            .tag(noFallbackTag)

                        ForEach(appState.selectableInputSources) { inputSource in
                            Text(inputSource.name)
                                .tag(inputSource.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Use current input source as global fallback") {
                        appState.useCurrentInputSourceAsGlobalFallback()
                    }
                    .disabled(appState.currentInputSourceId == nil)
                }
            }

            Section("Conflicts") {
                if appState.mappingConflicts.isEmpty {
                    Text("No mapping conflicts detected.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.mappingConflicts) { conflict in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(appState.deviceTitle(for: conflict.deviceKey)) -> \(appState.mappingConflictSourceName(for: conflict))")
                            Text("Reason: \(appState.mappingConflictReasonText(for: conflict))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Fix...") {
                                appState.openMappingFix(for: conflict.deviceKey)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Keyboard Device Mappings") {
                if appState.knownDeviceKeys.isEmpty {
                    Text("No keyboard devices recognized yet. Press a key on a keyboard to detect it.")
                        .foregroundStyle(.secondary)
                }

                ForEach(orderedDeviceKeys, id: \.self) { deviceKey in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.deviceTitle(for: deviceKey))
                            .font(.headline)

                        if appState.conflictFixTargetDeviceKey == deviceKey {
                            Text("Fix target")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

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

                            Picker("Device Fallback (Advanced)", selection: perDeviceFallbackSelectionBinding(for: deviceKey)) {
                                Text("No device fallback")
                                    .tag(noFallbackTag)

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
        .onAppear {
            appState.refreshInputSourcesNow()
        }
    }

    private var orderedDeviceKeys: [KeyboardDeviceKey] {
        guard let fixTarget = appState.conflictFixTargetDeviceKey else {
            return appState.knownDeviceKeys
        }

        var keys = appState.knownDeviceKeys
        if let index = keys.firstIndex(of: fixTarget) {
            keys.remove(at: index)
            keys.insert(fixTarget, at: 0)
        }
        return keys
    }

    private func mappingSelectionBinding(for deviceKey: KeyboardDeviceKey) -> Binding<String> {
        Binding(
            get: {
                guard let mappedInputSourceId = appState.mappedInputSourceId(for: deviceKey),
                      isSelectableInputSourceId(mappedInputSourceId) else {
                    return noAutoSwitchTag
                }

                return mappedInputSourceId
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

    private var globalFallbackSelectionBinding: Binding<String> {
        Binding(
            get: {
                guard let globalFallbackInputSourceId = appState.globalFallbackInputSourceId,
                      isSelectableInputSourceId(globalFallbackInputSourceId) else {
                    return noFallbackTag
                }

                return globalFallbackInputSourceId
            },
            set: { selection in
                if selection == noFallbackTag {
                    appState.setGlobalFallbackInputSourceId(nil)
                } else {
                    appState.setGlobalFallbackInputSourceId(selection)
                }
            }
        )
    }

    private func perDeviceFallbackSelectionBinding(for deviceKey: KeyboardDeviceKey) -> Binding<String> {
        Binding(
            get: {
                guard let perDeviceFallbackInputSourceId = appState.perDeviceFallbackInputSourceId(for: deviceKey),
                      isSelectableInputSourceId(perDeviceFallbackInputSourceId) else {
                    return noFallbackTag
                }

                return perDeviceFallbackInputSourceId
            },
            set: { selection in
                if selection == noFallbackTag {
                    appState.setPerDeviceFallback(for: deviceKey, inputSourceId: nil)
                } else {
                    appState.setPerDeviceFallback(for: deviceKey, inputSourceId: selection)
                }
            }
        )
    }

    private func isSelectableInputSourceId(_ inputSourceId: String) -> Bool {
        appState.selectableInputSources.contains(where: { $0.id == inputSourceId })
    }
}
