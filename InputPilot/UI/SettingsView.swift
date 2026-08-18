import SwiftUI

struct SettingsView: View {
    private let noAutoSwitchTag = "__NO_AUTO_SWITCH__"
    private let noFallbackTag = "__NO_FALLBACK__"

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Pause Auto-Switch",
                    isOn: Binding(
                        get: { appState.isAutoSwitchPaused },
                        set: { appState.setAutoSwitchPaused($0) }
                    )
                )

                Toggle(
                    "Switch on modifier-only key presses",
                    isOn: Binding(
                        get: { appState.switchOnModifierOnlyKeys },
                        set: { appState.setSwitchOnModifierOnlyKeys($0) }
                    )
                )

                LabeledContent("Last action", value: appState.lastAutoSwitchAction)

                if let error = appState.lastAutoSwitchError {
                    LabeledContent("Error") {
                        Text(error).foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Auto-Switch")
            } footer: {
                Text("When \"Switch on modifier-only key presses\" is off, a lone Shift, Command, or Option press (for example during Cmd+Tab) does not change the input source — only regular typing does.")
            }

            Section("Input Monitoring") {
                statusRow(appState.permissionLine)
                statusRow(appState.activeKeyboardLine)
                statusRow(appState.activeInputSourceLine)
            }

            Section("Input Sources") {
                LabeledContent("Current", value: appState.currentInputSourceName ?? "none")
                LabeledContent("Identifier", value: appState.currentInputSourceId ?? "none")
            }

            Section {
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

                    Button("Use current input source as global fallback") {
                        appState.useCurrentInputSourceAsGlobalFallback()
                    }
                    .disabled(appState.currentInputSourceId == nil)
                }
            } header: {
                Text("Fallbacks")
            } footer: {
                Text("Used when a device has no specific mapping.")
            }

            Section("Conflicts") {
                if appState.mappingConflicts.isEmpty {
                    Label("No mapping conflicts detected.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.mappingConflicts) { conflict in
                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text("\(appState.deviceTitle(for: conflict.deviceKey)) → \(appState.mappingConflictSourceName(for: conflict))")
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }

                            Text(appState.mappingConflictReasonText(for: conflict))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Fix…") {
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
                    deviceMappingRow(for: deviceKey)
                }
            }

            AboutSection()
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 520)
        .onAppear {
            appState.refreshInputSourcesNow()
        }
    }

    @ViewBuilder
    private func deviceMappingRow(for deviceKey: KeyboardDeviceKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(appState.deviceTitle(for: deviceKey))
                    .font(.headline)

                if appState.conflictFixTargetDeviceKey == deviceKey {
                    Text("Fix target")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                }
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

                Picker("Device Fallback (Advanced)", selection: perDeviceFallbackSelectionBinding(for: deviceKey)) {
                    Text("No device fallback")
                        .tag(noFallbackTag)

                    ForEach(appState.selectableInputSources) { inputSource in
                        Text(inputSource.name)
                            .tag(inputSource.id)
                    }
                }
            }

            Button("Forget device", role: .destructive) {
                appState.forgetDevice(deviceKey)
            }
        }
        .padding(.vertical, 4)
    }

    // ponytail: status lines arrive pre-composed from AppState; show as secondary rows.
    private func statusRow(_ line: String) -> some View {
        Text(line)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
