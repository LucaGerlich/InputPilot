import SwiftUI

struct SettingsView: View {
    let updaterService: UpdaterService

    private let notMappedTag = "__NOT_MAPPED__"
    private let noFallbackTag = "__NO_FALLBACK__"

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var loginItem: LoginItemController
    @State private var checksForUpdatesAutomatically = true

    var body: some View {
        Form {
            if appState.hasMappingConflicts {
                conflictsSection
            }

            keyboardsSection
            switchingSection
            fallbackSection
            updatesSection
            statusSection

            AboutSection()
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 520)
        .onAppear {
            appState.refreshInputSourcesNow()
            loginItem.refresh()
            checksForUpdatesAutomatically = updaterService.automaticallyChecksForUpdates
        }
        .onChange(of: checksForUpdatesAutomatically) { newValue in
            updaterService.automaticallyChecksForUpdates = newValue
        }
    }

    // MARK: - Sections

    private var conflictsSection: some View {
        Section("Needs Attention") {
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

                    Button("Choose Another Input Source") {
                        appState.openMappingFix(for: conflict.deviceKey)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var keyboardsSection: some View {
        Section {
            if appState.knownDeviceKeys.isEmpty {
                Text("Type a few keys on each keyboard you use, and it appears here.")
                    .foregroundStyle(.secondary)
            }

            ForEach(orderedDeviceKeys, id: \.self) { deviceKey in
                deviceMappingRow(for: deviceKey)
            }
        } header: {
            Text("Keyboards")
        } footer: {
            if appState.knownDeviceKeys.count < 2 {
                Text("InputPilot switches when you move between keyboards. Give this one an input source now; the next keyboard you type on appears here too.")
            }
        }
    }

    private var switchingSection: some View {
        Section {
            Toggle(
                "Automatic switching",
                isOn: Binding(
                    get: { appState.autoSwitchEnabled },
                    set: { appState.setAutoSwitchEnabled($0) }
                )
            )

            if let reason = appState.autoSwitchOffReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "Open InputPilot at login",
                isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                )
            )

            if loginItem.status == .requiresApproval {
                LabeledContent("Waiting for your approval in System Settings") {
                    Button("Open Login Items…") {
                        loginItem.openSystemSettingsLoginItems()
                    }
                }
            }

            if let error = loginItem.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Picker(
                "When you change the input source yourself",
                selection: Binding(
                    get: { appState.manualChangePolicy },
                    set: { appState.setManualChangePolicy($0) }
                )
            ) {
                ForEach(ManualChangePolicy.allCases) { policy in
                    Text(policy.title)
                        .tag(policy)
                }
            }

            Toggle(
                "Switch on modifier-only key presses",
                isOn: Binding(
                    get: { appState.switchOnModifierOnlyKeys },
                    set: { appState.setSwitchOnModifierOnlyKeys($0) }
                )
            )
        } header: {
            Text("Switching")
        } footer: {
            Text("A change counts as yours when anything but InputPilot makes it: ⌃Space, the input menu, Undo, or macOS's own \u{201C}Automatically switch to a document's input source\u{201D}. A lone Shift, Control, Option, or Command press only switches when modifier-only switching is on; any other key, including the Tab in Cmd+Tab, counts as typing on that keyboard.")
        }
    }

    private var fallbackSection: some View {
        Section {
            if appState.selectableInputSources.isEmpty {
                Text("No selectable input sources available.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Every other keyboard", selection: globalFallbackSelectionBinding) {
                    Text("No fallback")
                        .tag(noFallbackTag)

                    ForEach(appState.selectableInputSources) { inputSource in
                        Text(inputSource.name)
                            .tag(inputSource.id)
                    }
                }

                Button("Use Current Input Source for Every Other Keyboard") {
                    appState.useCurrentInputSourceAsGlobalFallback()
                }
                .disabled(appState.currentInputSourceId == nil)
            }
        } header: {
            Text("Fallbacks")
        } footer: {
            Text("A keyboard's own fallback is used when it has no input source or its input source was removed. This one covers every keyboard without either.")
        }
    }

    private var updatesSection: some View {
        Section {
            Toggle("Check for updates automatically", isOn: $checksForUpdatesAutomatically)

            Button("Check Now…") {
                updaterService.checkForUpdates()
            }
        } header: {
            Text("Updates")
        } footer: {
            Text("Asks GitHub about once a day whether a newer version exists. Nothing about your keyboards or typing is sent.")
        }
    }

    private var statusSection: some View {
        Section("Status") {
            statusRow(appState.permissionLine)
            statusRow(appState.monitorLine)
            statusRow(appState.activeKeyboardLine)
            statusRow(appState.activeInputSourceLine)
            LabeledContent("Last action", value: appState.lastAutoSwitchAction)

            if let error = appState.lastAutoSwitchError {
                LabeledContent("Error") {
                    Text(error).foregroundStyle(.red)
                }
            }

            if let hint = appState.keyboardMonitorHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !appState.isInputMonitoringGranted {
                Button("Open Input Monitoring Settings…") {
                    appState.openInputMonitoringSettings()
                }
            } else if !appState.isKeyboardMonitorRunning || appState.monitorHasPartialAccess {
                Button("Relaunch InputPilot") {
                    appState.relaunch()
                }
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func deviceMappingRow(for deviceKey: KeyboardDeviceKey) -> some View {
        let title = appState.deviceTitle(for: deviceKey)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)

                if appState.conflictFixTargetDeviceKey == deviceKey {
                    Text("Needs a new input source")
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
                Picker("Input source", selection: mappingSelectionBinding(for: deviceKey)) {
                    Text("Not mapped")
                        .tag(notMappedTag)

                    ForEach(appState.selectableInputSources) { inputSource in
                        Text(inputSource.name)
                            .tag(inputSource.id)
                    }
                }
                .accessibilityLabel("Input source for \(title)")

                Picker("Fallback", selection: perDeviceFallbackSelectionBinding(for: deviceKey)) {
                    Text("No fallback")
                        .tag(noFallbackTag)

                    ForEach(appState.selectableInputSources) { inputSource in
                        Text(inputSource.name)
                            .tag(inputSource.id)
                    }
                }
                .accessibilityLabel("Fallback input source for \(title)")
            }

            Button("Forget This Keyboard", role: .destructive) {
                appState.forgetDevice(deviceKey)
            }
            .accessibilityLabel("Forget \(title)")
        }
        .padding(.vertical, 4)
    }

    // ponytail: status lines arrive pre-composed from AppState; show as secondary rows.
    private func statusRow(_ line: String) -> some View {
        Text(line)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bindings

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
                    return notMappedTag
                }

                return mappedInputSourceId
            },
            set: { selection in
                appState.setMapping(for: deviceKey, inputSourceId: selection == notMappedTag ? nil : selection)
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
                appState.setGlobalFallbackInputSourceId(selection == noFallbackTag ? nil : selection)
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
                appState.setPerDeviceFallback(for: deviceKey, inputSourceId: selection == noFallbackTag ? nil : selection)
            }
        )
    }

    private func isSelectableInputSourceId(_ inputSourceId: String) -> Bool {
        appState.selectableInputSources.contains(where: { $0.id == inputSourceId })
    }
}
