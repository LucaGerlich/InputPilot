import SwiftUI

struct SettingsView: View {
    private let noAutoSwitchTag = "__NO_AUTO_SWITCH__"
    private let noFallbackTag = "__NO_FALLBACK__"
    private let rowLabelWidth: CGFloat = 170

    @EnvironmentObject private var appState: AppState
    @State private var newProfileName = ""
    @State private var renameProfileName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox("Auto-Switch") {
                    VStack(alignment: .leading, spacing: 10) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Global Hotkeys") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(appState.hotkeyActions) { action in
                            row(action.title) {
                                Picker(action.title, selection: hotkeySelectionBinding(for: action)) {
                                    ForEach(appState.availableHotkeyCombos(for: action)) { combo in
                                        Text(combo.displayName)
                                            .tag(combo.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        Text(appState.hotkeyStatusLine)
                            .foregroundStyle(.secondary)

                        if let hotkeyRegistrationError = appState.hotkeyRegistrationError {
                            Text(hotkeyRegistrationError)
                                .foregroundStyle(.red)
                            Text("Fallback: use menu and settings actions manually.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Profiles") {
                    VStack(alignment: .leading, spacing: 10) {
                        row("Active Profile") {
                            Picker("Active Profile", selection: activeProfileSelectionBinding) {
                                ForEach(appState.profiles) { profile in
                                    Text(profile.name).tag(profile.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        row("Create") {
                            HStack(spacing: 8) {
                                TextField("New profile name", text: $newProfileName)
                                Button("Create") {
                                    appState.createProfile(named: newProfileName)
                                    newProfileName = ""
                                    syncRenameFieldToActiveProfile()
                                }
                                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        row("Rename") {
                            HStack(spacing: 8) {
                                TextField("Rename active profile", text: $renameProfileName)
                                Button("Rename") {
                                    appState.renameActiveProfile(to: renameProfileName)
                                    syncRenameFieldToActiveProfile()
                                }
                                .disabled(renameProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        row("Delete") {
                            Button("Delete Active Profile", role: .destructive) {
                                appState.deleteActiveProfile()
                                syncRenameFieldToActiveProfile()
                            }
                            .disabled(!appState.canDeleteActiveProfile)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Input Monitoring") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.permissionLine)
                        Text(appState.activeKeyboardLine)
                        Text(appState.activeInputSourceLine)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Input Sources") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current: \(appState.currentInputSourceName ?? "none")")
                        Text("ID: \(appState.currentInputSourceId ?? "none")")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Fallbacks") {
                    VStack(alignment: .leading, spacing: 10) {
                        if appState.selectableInputSources.isEmpty {
                            Text("No selectable input sources available.")
                                .foregroundStyle(.secondary)
                        } else {
                            row("Global Fallback") {
                                Picker("Global Fallback", selection: globalFallbackSelectionBinding) {
                                    Text("No global fallback")
                                        .tag(noFallbackTag)

                                    ForEach(appState.selectableInputSources) { inputSource in
                                        Text(inputSource.name)
                                            .tag(inputSource.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            row("") {
                                Button("Use current input source as global fallback") {
                                    appState.useCurrentInputSourceAsGlobalFallback()
                                }
                                .disabled(appState.currentInputSourceId == nil)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Conflicts") {
                    VStack(alignment: .leading, spacing: 8) {
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
                                .padding(8)
                                .background(.quaternary.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Keyboard Device Mappings") {
                    VStack(alignment: .leading, spacing: 12) {
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
                                    row("Input Source") {
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

                                    row("Device Fallback") {
                                        Picker("Device Fallback", selection: perDeviceFallbackSelectionBinding(for: deviceKey)) {
                                            Text("No device fallback")
                                                .tag(noFallbackTag)

                                            ForEach(appState.selectableInputSources) { inputSource in
                                                Text(inputSource.name)
                                                    .tag(inputSource.id)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }

                                Button("Forget device", role: .destructive) {
                                    appState.forgetDevice(deviceKey)
                                }
                            }
                            .padding(10)
                            .background(.quaternary.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(minWidth: 640, minHeight: 520)
        .onAppear {
            appState.refreshInputSourcesNow()
            syncRenameFieldToActiveProfile()
        }
        .onChange(of: appState.activeProfileId) { _, _ in
            syncRenameFieldToActiveProfile()
        }
    }

    @ViewBuilder
    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .foregroundStyle(label.isEmpty ? .clear : .primary)
                .frame(width: rowLabelWidth, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var activeProfileSelectionBinding: Binding<String> {
        Binding(
            get: { appState.activeProfileId },
            set: { appState.setActiveProfile($0) }
        )
    }

    private func hotkeySelectionBinding(for action: HotkeyAction) -> Binding<String> {
        Binding(
            get: { appState.hotkeyCombo(for: action).id },
            set: { selection in
                if let combo = appState.availableHotkeyCombos(for: action).first(where: { $0.id == selection }) {
                    appState.setHotkeyCombo(combo, for: action)
                }
            }
        )
    }

    private func syncRenameFieldToActiveProfile() {
        renameProfileName = appState.activeProfileName
    }
}
