import Foundation
import Combine
import AppKit
import IOKit.hid
import UserNotifications
#if DEBUG
import OSLog
#endif

@MainActor
final class AppState: ObservableObject {
    private static let autoSwitchEnabledDefaultsKey = "autoSwitchEnabled"
    private static let pauseUntilDefaultsKey = "autoSwitchPauseUntil"
    private static let globalFallbackInputSourceIdDefaultsKey = "globalFallbackInputSourceId"
    private static let deviceFilterRuleDefaultsKey = "deviceFilterRule"
    private static let showNotificationOnSwitchDefaultsKey = "showNotificationOnSwitch"
    private static let syncViaICloudDriveDefaultsKey = "syncViaICloudDriveEnabled"
    private static let inputSourcePollIntervalSeconds: TimeInterval = 6

    @Published private(set) var status = InputStatusSnapshot.placeholder
    @Published private(set) var profiles: [Profile]
    @Published private(set) var activeProfileId: String
    @Published private(set) var activeKeyboardDevice: ActiveKeyboardDevice?
    @Published private(set) var currentInputSourceId: String?
    @Published private(set) var currentInputSourceName: String?
    @Published private(set) var enabledInputSources: [InputSourceInfo] = []
    @Published private(set) var allInputSources: [InputSourceInfo] = []
    @Published private(set) var knownDeviceKeys: [KeyboardDeviceKey] = []
    @Published private(set) var mappingConflicts: [MappingConflict] = []
    @Published private(set) var conflictFixTargetDeviceKey: KeyboardDeviceKey?
    @Published private(set) var globalFallbackInputSourceId: String?
    @Published private(set) var autoSwitchEnabled: Bool
    @Published private(set) var pauseUntil: Date?
    @Published private(set) var lastAction: SwitchAction?
    @Published private(set) var previousInputSourceIdBeforeLastSwitch: String?
    @Published private(set) var activeTemporaryOverride: TemporaryOverride?
    @Published private(set) var hotkeyAssignments: [HotkeyAction: KeyCombo] = [:]
    @Published private(set) var hotkeyStatusLine = "Global hotkeys are unavailable."
    @Published private(set) var hotkeyRegistrationError: String?
    @Published private(set) var debugLogEntries: [LogEntry] = []
    @Published private(set) var lastAutoSwitchAction = "No auto-switch action yet."
    @Published private(set) var lastAutoSwitchError: String?
    @Published private(set) var deviceFilterRule: DeviceFilterRule
    @Published private(set) var showNotificationOnSwitch: Bool
    @Published private(set) var notificationPermissionHint: String?
    @Published private(set) var backupStatusLine = "No backup activity yet."
    @Published private(set) var backupErrorMessage: String?
    @Published private(set) var syncViaICloudDriveEnabled: Bool
    @Published private(set) var isICloudDriveAvailable: Bool
    @Published private(set) var iCloudDriveSyncHint: String?

    private let permissionService: PermissionServicing
    private let hidKeyboardMonitor: HIDKeyboardMonitoring
    private let inputSourceService: InputSourceServicing
    private let profileManager: ProfileManaging
    private let mappingStore: MappingStoring
    private let temporaryOverrideStore: TemporaryOverrideStoring
    private let globalHotkeyService: GlobalHotkeyServicing
    private let notificationService: NotificationServicing
    private let iCloudDriveSyncService: ICloudDriveSyncServicing
    private let appSettingsStore: AppSettingsStore
    private let clock: ClockProviding
    private let debugLogService: DebugLogServicing
    private let switchController: SwitchController

    private var detectedDevicesByKey: [KeyboardDeviceKey: ActiveKeyboardDevice] = [:]
    private var permissionRefreshTask: Task<Void, Never>?
    private var iCloudSyncTask: Task<Void, Never>?
    private var lastICloudSyncedBackupData: Data?
    private var isApplyingBackupSnapshot = false
    private var lastMonitorStartFailure: String?
    private var lastInputSourceRefreshAt = Date.distantPast

#if DEBUG
    private let logger = Logger(subsystem: "InputPilot", category: "AppState")
#endif

    init(
        permissionService: PermissionServicing,
        hidKeyboardMonitor: HIDKeyboardMonitoring,
        inputSourceService: InputSourceServicing,
        profileManager: ProfileManaging,
        mappingStore: MappingStoring,
        temporaryOverrideStore: TemporaryOverrideStoring? = nil,
        globalHotkeyService: GlobalHotkeyServicing,
        notificationService: NotificationServicing,
        iCloudDriveSyncService: ICloudDriveSyncServicing,
        appSettingsStore: AppSettingsStore,
        clock: ClockProviding,
        debugLogService: DebugLogServicing
    ) {
        self.permissionService = permissionService
        self.hidKeyboardMonitor = hidKeyboardMonitor
        self.inputSourceService = inputSourceService
        self.profileManager = profileManager
        self.mappingStore = mappingStore
        self.temporaryOverrideStore = temporaryOverrideStore ?? TemporaryOverrideStore()
        self.globalHotkeyService = globalHotkeyService
        self.notificationService = notificationService
        self.iCloudDriveSyncService = iCloudDriveSyncService
        self.appSettingsStore = appSettingsStore
        self.clock = clock
        self.debugLogService = debugLogService
        self.switchController = SwitchController(clock: clock)
        self.profiles = profileManager.profiles
        self.activeProfileId = profileManager.activeProfileId
        self.autoSwitchEnabled = appSettingsStore.bool(
            forKey: Self.autoSwitchEnabledDefaultsKey,
            default: true
        )
        self.pauseUntil = appSettingsStore.date(forKey: Self.pauseUntilDefaultsKey)
        self.globalFallbackInputSourceId = Self.normalizedInputSourceId(
            appSettingsStore.string(forKey: Self.globalFallbackInputSourceIdDefaultsKey)
        )
        self.deviceFilterRule = Self.loadPersistedDeviceFilterRule(from: appSettingsStore)
        self.showNotificationOnSwitch = appSettingsStore.bool(
            forKey: Self.showNotificationOnSwitchDefaultsKey,
            default: false
        )
        self.syncViaICloudDriveEnabled = appSettingsStore.bool(
            forKey: Self.syncViaICloudDriveDefaultsKey,
            default: false
        )
        self.isICloudDriveAvailable = iCloudDriveSyncService.isAvailable
        self.debugLogEntries = debugLogService.entries
        self.hotkeyAssignments = loadPersistedHotkeyAssignments()

        seedKnownDevicesFromMappings()
        self.temporaryOverrideStore.clearExpired(now: clock.now)
        configureGlobalHotkeys()
        refreshPauseStateIfNeeded()
        refreshPermissionStatus()
        refreshInputSourceState()
        refreshActiveTemporaryOverride()
        Task { [weak self] in
            await self?.refreshNotificationPermissionStatus(requestIfNeeded: false)
        }
        if syncViaICloudDriveEnabled {
            bootstrapICloudSyncAfterEnable()
        } else if !isICloudDriveAvailable {
            iCloudDriveSyncHint = "iCloud Drive is not available on this Mac."
        }
        startPermissionMonitoring()

        if !isAutoSwitchActive {
            if !autoSwitchEnabled {
                recordAction("Auto-switch is currently disabled.")
            } else if let pauseUntil {
                recordAction("Auto-switch paused until \(formattedTime(pauseUntil)).")
            }
        }
    }

    convenience init() {
        let profileManager = ProfileManager()
        self.init(
            permissionService: PermissionService(),
            hidKeyboardMonitor: HIDKeyboardMonitor(),
            inputSourceService: InputSourceService(),
            profileManager: profileManager,
            mappingStore: MappingStore(profileManager: profileManager),
            globalHotkeyService: GlobalHotkeyService(),
            notificationService: NotificationService(),
            iCloudDriveSyncService: ICloudDriveSyncService(),
            appSettingsStore: AppSettingsStore(),
            clock: SystemClock(),
            debugLogService: DebugLogService()
        )
    }

    convenience init(
        permissionService: PermissionServicing,
        hidKeyboardMonitor: HIDKeyboardMonitoring,
        inputSourceService: InputSourceServicing,
        mappingStore: MappingStoring,
        temporaryOverrideStore: TemporaryOverrideStoring? = nil,
        globalHotkeyService: GlobalHotkeyServicing? = nil,
        notificationService: NotificationServicing? = nil,
        iCloudDriveSyncService: ICloudDriveSyncServicing? = nil,
        appSettingsStore: AppSettingsStore,
        clock: ClockProviding,
        profileManager: ProfileManaging? = nil
    ) {
        let resolvedProfileManager = profileManager ?? ProfileManager()
        let resolvedTemporaryOverrideStore = temporaryOverrideStore
            ?? TemporaryOverrideStore(defaults: appSettingsStore.userDefaults)
        let resolvedGlobalHotkeyService = globalHotkeyService ?? NoOpGlobalHotkeyService()
        let resolvedNotificationService = notificationService ?? NoOpNotificationService()
        let resolvedICloudDriveSyncService = iCloudDriveSyncService ?? NoOpICloudDriveSyncService()
        self.init(
            permissionService: permissionService,
            hidKeyboardMonitor: hidKeyboardMonitor,
            inputSourceService: inputSourceService,
            profileManager: resolvedProfileManager,
            mappingStore: mappingStore,
            temporaryOverrideStore: resolvedTemporaryOverrideStore,
            globalHotkeyService: resolvedGlobalHotkeyService,
            notificationService: resolvedNotificationService,
            iCloudDriveSyncService: resolvedICloudDriveSyncService,
            appSettingsStore: appSettingsStore,
            clock: clock,
            debugLogService: DebugLogService()
        )
    }

    deinit {
        permissionRefreshTask?.cancel()
        iCloudSyncTask?.cancel()
    }

    var permissionLine: String {
        "Permission: \(status.permissionStatus.rawValue)"
    }

    var monitorLine: String {
        "Monitor: \(hidKeyboardMonitor.isRunning ? "running" : "stopped")"
    }

    var activeKeyboardLine: String {
        "Active device: \(status.activeKeyboard)"
    }

    var activeInputSourceLine: String {
        "Current source: \(status.activeInputSource)"
    }

    var isInputMonitoringGranted: Bool {
        status.permissionStatus == .granted
    }

    var isAutoSwitchActive: Bool {
        guard autoSwitchEnabled else {
            return false
        }

        guard let pauseUntil else {
            return true
        }

        return pauseUntil < clock.now
    }

    var isAutoSwitchPaused: Bool {
        guard let pauseUntil else {
            return false
        }

        return pauseUntil >= clock.now
    }

    var canUndoLastSwitch: Bool {
        lastAction != nil && previousInputSourceIdBeforeLastSwitch != nil
    }

    var permissionWarningMessage: String {
        switch status.permissionStatus {
        case .denied:
            return "Input Monitoring permission is denied or was revoked."
        case .unknown:
            return "Input Monitoring permission has not been granted yet."
        case .granted:
            if let monitorError = hidKeyboardMonitor.lastStartErrorMessage, !hidKeyboardMonitor.isRunning {
                return "Input Monitoring is granted, but monitor is unavailable: \(monitorError)"
            }
            return "Input Monitoring is granted."
        }
    }

    var keyboardMonitorHint: String? {
        if !isInputMonitoringGranted {
            return "Keyboard monitor paused: Input Monitoring permission is required."
        }

        if !hidKeyboardMonitor.isRunning {
            if let monitorError = hidKeyboardMonitor.lastStartErrorMessage {
                return monitorError
            }
            return "Keyboard monitor is unavailable right now."
        }

        if activeKeyboardDevice == nil {
            return "Press any key to detect the active keyboard device."
        }

        return nil
    }

    var activeProfileName: String {
        profiles.first(where: { $0.id == activeProfileId })?.name ?? "Unknown"
    }

    var canDeleteActiveProfile: Bool {
        profiles.count > 1
    }

    var selectableInputSources: [InputSourceInfo] {
        enabledInputSources.filter { $0.isSelectable }
    }

    var hasMappingConflicts: Bool {
        !mappingConflicts.isEmpty
    }

    var hasActiveTemporaryOverride: Bool {
        activeTemporaryOverride != nil
    }

    var canSyncViaICloudDrive: Bool {
        isICloudDriveAvailable
    }

    var deviceFilterMode: DeviceFilterRule.Mode {
        deviceFilterRule.mode
    }

    var deviceFilterModes: [DeviceFilterRule.Mode] {
        DeviceFilterRule.Mode.allCases
    }

    var hotkeyActions: [HotkeyAction] {
        HotkeyAction.allCases
    }

    func availableHotkeyCombos(for action: HotkeyAction) -> [KeyCombo] {
        var combos = KeyCombo.predefinedCombos
        let currentCombo = hotkeyAssignments[action] ?? action.defaultKeyCombo
        if !combos.contains(currentCombo) {
            combos.insert(currentCombo, at: 0)
        }
        return combos
    }

    func hotkeyCombo(for action: HotkeyAction) -> KeyCombo {
        hotkeyAssignments[action] ?? action.defaultKeyCombo
    }

    func requestInputMonitoringPermission() {
        _ = permissionService.requestInputMonitoring()
        refreshPermissionStatus()
    }

    func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func copyDebugLogToClipboard() {
        let payload = debugLogService.export()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        logInfo(category: "debug", message: "Copied debug log to clipboard.")
    }

    func exportDebugLog(to url: URL) {
        let payload = debugLogService.export()
        do {
            try payload.write(to: url, atomically: true, encoding: .utf8)
            logInfo(category: "debug", message: "Exported debug log to \(url.lastPathComponent).")
        } catch {
            let message = "Debug log export failed: \(error.localizedDescription)"
            logError(category: "debug", message: message)
            recordFailure(message)
        }
    }

    func exportBackup(to url: URL) {
        do {
            let data = try serializedBackupData()
            try data.write(to: url, options: [.atomic])
            backupErrorMessage = nil
            backupStatusLine = "Exported backup to \(url.lastPathComponent)."
            recordAction("Exported backup to \(url.lastPathComponent).")
        } catch {
            let message = "Backup export failed: \(error.localizedDescription)"
            backupErrorMessage = message
            backupStatusLine = "Backup export failed."
            recordFailure(message)
        }
    }

    func importBackup(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let snapshot = try AppBackupMigrator.decodeSnapshot(from: data)
            try applyBackupSnapshot(snapshot, sourceDescription: url.lastPathComponent)
            backupErrorMessage = nil
            backupStatusLine = "Imported backup from \(url.lastPathComponent)."
            recordAction("Imported backup from \(url.lastPathComponent).")
            scheduleICloudSyncIfNeeded()
        } catch {
            let message = "Backup import failed: \(error.localizedDescription)"
            backupErrorMessage = message
            backupStatusLine = "Backup import failed."
            recordFailure(message)
        }
    }

    func setSyncViaICloudDriveEnabled(_ enabled: Bool) {
        guard syncViaICloudDriveEnabled != enabled else {
            return
        }

        isICloudDriveAvailable = iCloudDriveSyncService.isAvailable
        if enabled, !isICloudDriveAvailable {
            syncViaICloudDriveEnabled = false
            appSettingsStore.set(false, forKey: Self.syncViaICloudDriveDefaultsKey)
            iCloudDriveSyncHint = "iCloud Drive is unavailable. Sign in to iCloud Drive to enable sync."
            backupErrorMessage = nil
            backupStatusLine = "iCloud sync unavailable."
            return
        }

        syncViaICloudDriveEnabled = enabled
        appSettingsStore.set(enabled, forKey: Self.syncViaICloudDriveDefaultsKey)

        if enabled {
            iCloudDriveSyncHint = "iCloud sync enabled."
            recordAction("Enabled iCloud Drive sync.")
            bootstrapICloudSyncAfterEnable()
        } else {
            iCloudSyncTask?.cancel()
            iCloudDriveSyncHint = nil
            recordAction("Disabled iCloud Drive sync.")
        }
    }

    func logConflictWarning(_ message: String) {
        logWarn(category: "conflict", message: message)
    }

    func setActiveProfile(_ profileId: String) {
        guard profileId != activeProfileId else {
            return
        }

        guard profiles.contains(where: { $0.id == profileId }) else {
            return
        }

        profileManager.setActiveProfile(id: profileId)
        handleProfileContextChange(actionMessage: "Switched profile to \(activeProfileName).")
    }

    func createProfile(named name: String) {
        let profile = profileManager.createProfile(name: name)
        profileManager.setActiveProfile(id: profile.id)
        handleProfileContextChange(actionMessage: "Created profile \(profile.name).")
    }

    func renameActiveProfile(to name: String) {
        profileManager.renameProfile(id: activeProfileId, name: name)
        refreshProfileState()
        recordAction("Renamed active profile to \(activeProfileName).")
    }

    func deleteActiveProfile() {
        deleteProfile(activeProfileId)
    }

    func deleteProfile(_ profileId: String) {
        guard let profileName = profiles.first(where: { $0.id == profileId })?.name else {
            return
        }

        guard profileManager.deleteProfile(id: profileId) else {
            recordFailure("Cannot delete profile: at least one profile must remain.")
            return
        }

        mappingStore.removeProfileData(profileId: profileId)
        handleProfileContextChange(actionMessage: "Deleted profile \(profileName).")
    }

    func setAutoSwitchEnabled(_ enabled: Bool) {
        guard autoSwitchEnabled != enabled else {
            return
        }

        autoSwitchEnabled = enabled
        appSettingsStore.set(enabled, forKey: Self.autoSwitchEnabledDefaultsKey)

        if !enabled {
            switchController.reset()
            recordAction("Auto-switch disabled.")
            return
        }

        recordAction("Auto-switch enabled.")

        if isAutoSwitchActive, let activeKeyboardDevice {
            evaluateSwitch(for: KeyboardDeviceKey(device: activeKeyboardDevice), eventKind: .deviceStabilized)
        }
    }

    func pause(minutes: Int) {
        guard minutes > 0 else {
            return
        }

        let until = clock.now.addingTimeInterval(TimeInterval(minutes * 60))
        pauseUntil = until
        appSettingsStore.set(until, forKey: Self.pauseUntilDefaultsKey)
        switchController.reset()
        recordAction("Auto-switch paused until \(formattedTime(until)).")
    }

    func resume() {
        guard pauseUntil != nil else {
            return
        }

        pauseUntil = nil
        appSettingsStore.set(Optional<Date>.none, forKey: Self.pauseUntilDefaultsKey)
        recordAction("Auto-switch resumed.")

        if isAutoSwitchActive, let activeKeyboardDevice {
            evaluateSwitch(for: KeyboardDeviceKey(device: activeKeyboardDevice), eventKind: .deviceStabilized)
        }
    }

    func setAutoSwitchPaused(_ paused: Bool) {
        if paused {
            pause(minutes: 60 * 24 * 365)
        } else {
            resume()
        }
    }

    func setDeviceFilterMode(_ mode: DeviceFilterRule.Mode) {
        guard deviceFilterRule.mode != mode else {
            return
        }

        deviceFilterRule.mode = mode
        persistDeviceFilterRule()
        recordAction("Device filter mode set to \(mode.displayName).")
        reevaluateForActiveDeviceAfterFilterChange()
    }

    func isDeviceEnabledForAutoSwitch(_ deviceKey: KeyboardDeviceKey) -> Bool {
        deviceFilterRule.isDeviceEnabled(deviceKey.fingerprint)
    }

    func setDeviceEnabledForAutoSwitch(_ enabled: Bool, for deviceKey: KeyboardDeviceKey) {
        var updatedRule = deviceFilterRule
        updatedRule.setDeviceEnabled(enabled, for: deviceKey.fingerprint)
        guard updatedRule != deviceFilterRule else {
            return
        }

        deviceFilterRule = updatedRule
        persistDeviceFilterRule()
        let stateLabel = enabled ? "enabled" : "disabled"
        recordAction("Auto-switch \(stateLabel) for \(deviceTitle(for: deviceKey)).")
        reevaluateForActiveDeviceAfterFilterChange()
    }

    func setShowNotificationOnSwitch(_ enabled: Bool) {
        guard showNotificationOnSwitch != enabled else {
            return
        }

        showNotificationOnSwitch = enabled
        appSettingsStore.set(enabled, forKey: Self.showNotificationOnSwitchDefaultsKey)

        if enabled {
            recordAction("Switch notifications enabled.")
            Task { [weak self] in
                await self?.refreshNotificationPermissionStatus(requestIfNeeded: true)
            }
        } else {
            notificationPermissionHint = nil
            recordAction("Switch notifications disabled.")
        }
    }

    func setHotkeyCombo(_ combo: KeyCombo, for action: HotkeyAction) {
        if let conflictingAction = hotkeyAssignments.first(where: { $0.key != action && $0.value == combo })?.key {
            hotkeyRegistrationError = "Shortcut conflict: \(combo.displayName) is already used for \(conflictingAction.title)."
            hotkeyStatusLine = "Global hotkeys need attention."
            return
        }

        hotkeyAssignments[action] = combo
        persistHotkeyCombo(combo, for: action)
        applyGlobalHotkeys()
        recordAction("Updated hotkey for \(action.title) to \(combo.displayName).")
    }

    func selectInputSource(_ id: String) {
        let sourceName = inputSourceDisplayName(for: id)

        guard attemptSelectInputSource(id: id, reason: "manual select") else {
            recordFailure("Failed to select input source: \(sourceName).")
            return
        }

        refreshInputSourceState()
        clearLastError()
        recordAction("Selected input source: \(sourceName).")
    }

    func undoLastSwitch() {
        guard let previousInputSourceIdBeforeLastSwitch, let lastAction else {
            return
        }

        let previousSourceName = inputSourceDisplayName(for: previousInputSourceIdBeforeLastSwitch)
        guard attemptSelectInputSource(id: previousInputSourceIdBeforeLastSwitch, reason: "undo") else {
            recordFailure("Undo failed for \(lastAction.deviceDisplayName) -> \(previousSourceName).")
            return
        }

        refreshInputSourceState()
        self.previousInputSourceIdBeforeLastSwitch = nil
        self.lastAction = nil
        clearLastError()
        recordAction("Undid last switch: \(lastAction.deviceDisplayName) -> \(previousSourceName).")
    }

    func useCurrentInputSourceForActiveDeviceMapping() {
        guard let deviceKey = activeDeviceKeyForTemporaryOverride() else {
            recordFailure("Cannot map current source: no active keyboard device.")
            return
        }

        guard let currentInputSourceId else {
            recordFailure("Cannot map current source: no active input source.")
            return
        }

        guard inputSourceService.existsEnabledInputSource(id: currentInputSourceId) else {
            recordFailure("Cannot map current source: current input source is not enabled.")
            return
        }

        setMapping(for: deviceKey, inputSourceId: currentInputSourceId)
    }

    func mappedInputSourceId(for deviceKey: KeyboardDeviceKey) -> String? {
        mappingStore.getMapping(for: deviceKey)
    }

    func perDeviceFallbackInputSourceId(for deviceKey: KeyboardDeviceKey) -> String? {
        mappingStore.getPerDeviceFallback(for: deviceKey)
    }

    func setGlobalFallbackInputSourceId(_ inputSourceId: String?) {
        let normalizedInputSourceId = Self.normalizedInputSourceId(inputSourceId)
        guard globalFallbackInputSourceId != normalizedInputSourceId else {
            return
        }

        globalFallbackInputSourceId = normalizedInputSourceId
        appSettingsStore.set(normalizedInputSourceId, forKey: Self.globalFallbackInputSourceIdDefaultsKey)

        if let normalizedInputSourceId {
            recordAction("Global fallback set to \(inputSourceDisplayName(for: normalizedInputSourceId)).")
        } else {
            recordAction("Global fallback cleared.")
        }

        if let activeKeyboardDevice {
            evaluateSwitch(for: KeyboardDeviceKey(device: activeKeyboardDevice), eventKind: .deviceStabilized)
        }
    }

    func useCurrentInputSourceAsGlobalFallback() {
        guard let currentInputSourceId else {
            recordFailure("Cannot set global fallback: no current input source.")
            return
        }

        guard inputSourceService.existsEnabledInputSource(id: currentInputSourceId) else {
            recordFailure("Cannot set global fallback: current input source is not enabled.")
            return
        }

        setGlobalFallbackInputSourceId(currentInputSourceId)
    }

    func lockCurrentInputSourceForActiveKeyboardUntilRestart() {
        guard let deviceKey = activeDeviceKeyForTemporaryOverride() else {
            recordFailure("Cannot set temporary lock: no active keyboard.")
            return
        }

        guard let currentInputSourceId else {
            recordFailure("Cannot set temporary lock: no current input source.")
            return
        }

        guard inputSourceService.existsEnabledInputSource(id: currentInputSourceId) else {
            recordFailure("Cannot set temporary lock: current input source is not enabled.")
            return
        }

        temporaryOverrideStore.setOverride(
            deviceFingerprintKey: deviceKey.primaryIdentifier,
            inputSourceId: currentInputSourceId,
            expiresAt: nil,
            persistAcrossLaunch: false
        )
        refreshActiveTemporaryOverride(for: deviceKey)
        clearLastError()
        recordAction(
            "Locked \(deviceTitle(for: deviceKey)) to \(inputSourceDisplayName(for: currentInputSourceId)) until restart."
        )
        evaluateSwitch(for: deviceKey, eventKind: .deviceStabilized)
    }

    func lockCurrentInputSourceForActiveKeyboardUntilEndOfDay() {
        guard let deviceKey = activeDeviceKeyForTemporaryOverride() else {
            recordFailure("Cannot set temporary lock: no active keyboard.")
            return
        }

        guard let currentInputSourceId else {
            recordFailure("Cannot set temporary lock: no current input source.")
            return
        }

        guard inputSourceService.existsEnabledInputSource(id: currentInputSourceId) else {
            recordFailure("Cannot set temporary lock: current input source is not enabled.")
            return
        }

        guard let endOfToday = endOfToday(from: clock.now), endOfToday > clock.now else {
            recordFailure("Cannot set temporary lock: end-of-day timestamp is not valid.")
            return
        }

        temporaryOverrideStore.setOverride(
            deviceFingerprintKey: deviceKey.primaryIdentifier,
            inputSourceId: currentInputSourceId,
            expiresAt: endOfToday,
            persistAcrossLaunch: true
        )
        refreshActiveTemporaryOverride(for: deviceKey)
        clearLastError()
        recordAction(
            "Locked \(deviceTitle(for: deviceKey)) to \(inputSourceDisplayName(for: currentInputSourceId)) until \(formattedTime(endOfToday))."
        )
        evaluateSwitch(for: deviceKey, eventKind: .deviceStabilized)
    }

    func clearTemporaryOverrideForActiveKeyboard() {
        guard let deviceKey = activeDeviceKeyForTemporaryOverride() else {
            recordFailure("Cannot clear temporary lock: no active keyboard.")
            return
        }

        temporaryOverrideStore.clearOverride(for: deviceKey.primaryIdentifier)
        refreshActiveTemporaryOverride(for: deviceKey)
        clearLastError()
        recordAction("Cleared temporary lock for \(deviceTitle(for: deviceKey)).")
        evaluateSwitch(for: deviceKey, eventKind: .deviceStabilized)
    }

    func setMapping(for deviceKey: KeyboardDeviceKey, inputSourceId: String?) {
        if let inputSourceId, !inputSourceId.isEmpty {
            mappingStore.setMapping(deviceKey: deviceKey, inputSourceId: inputSourceId)
            let sourceName = inputSourceDisplayName(for: inputSourceId)
            recordAction("Saved mapping for \(deviceTitle(for: deviceKey)) -> \(sourceName).")
            clearLastError()
        } else {
            mappingStore.removeMapping(deviceKey: deviceKey)
            recordAction("Removed mapping for \(deviceTitle(for: deviceKey)).")
            clearLastError()
        }

        refreshMappingConflicts(usingEnabledSources: enabledInputSources)

        if let activeKeyboardDevice,
           isCurrentActiveDeviceRepresented(by: deviceKey, activeKeyboardDevice: activeKeyboardDevice) {
            evaluateSwitch(for: deviceKey, eventKind: .deviceStabilized)
        }
    }

    func setPerDeviceFallback(for deviceKey: KeyboardDeviceKey, inputSourceId: String?) {
        let normalizedInputSourceId = Self.normalizedInputSourceId(inputSourceId)
        mappingStore.setPerDeviceFallback(deviceKey: deviceKey, inputSourceId: normalizedInputSourceId)

        if !knownDeviceKeys.contains(deviceKey) {
            knownDeviceKeys.append(deviceKey)
            sortKnownDevices()
        }

        if let normalizedInputSourceId {
            recordAction("Saved fallback for \(deviceTitle(for: deviceKey)) -> \(inputSourceDisplayName(for: normalizedInputSourceId)).")
        } else {
            recordAction("Removed fallback for \(deviceTitle(for: deviceKey)).")
        }
        clearLastError()

        if let activeKeyboardDevice,
           isCurrentActiveDeviceRepresented(by: deviceKey, activeKeyboardDevice: activeKeyboardDevice) {
            evaluateSwitch(for: deviceKey, eventKind: .deviceStabilized)
        }
    }

    func forgetDevice(_ deviceKey: KeyboardDeviceKey) {
        mappingStore.removeMapping(deviceKey: deviceKey)
        mappingStore.setPerDeviceFallback(deviceKey: deviceKey, inputSourceId: nil)
        temporaryOverrideStore.clearOverride(for: deviceKey.primaryIdentifier)
        detectedDevicesByKey.removeValue(forKey: deviceKey)
        knownDeviceKeys.removeAll { $0 == deviceKey }
        if conflictFixTargetDeviceKey == deviceKey {
            conflictFixTargetDeviceKey = nil
        }
        refreshMappingConflicts(usingEnabledSources: enabledInputSources)
        refreshActiveTemporaryOverride()
        recordAction("Forgot device: \(deviceTitle(for: deviceKey)).")
        clearLastError()
    }

    func deviceTitle(for deviceKey: KeyboardDeviceKey) -> String {
        if let detectedDevice = detectedDevicesByKey[deviceKey] {
            return detectedDevice.displayName
        }

        if let productName = deviceKey.productName, !productName.isEmpty {
            return productName
        }

        if deviceKey.isBuiltIn {
            return "Built-in keyboard"
        }

        return "Keyboard VID \(deviceKey.vendorId), PID \(deviceKey.productId)"
    }

    func deviceSubtitle(for deviceKey: KeyboardDeviceKey) -> String {
        var parts = ["VID \(deviceKey.vendorId)", "PID \(deviceKey.productId)"]

        if let transport = deviceKey.transport, !transport.isEmpty {
            parts.append(transport)
        }

        if deviceKey.isBuiltIn {
            parts.append("Built-in")
        }

        let locationId = detectedDevicesByKey[deviceKey]?.locationId ?? deviceKey.locationId
        if let locationId {
            parts.append("Location \(locationId)")
        }

        return parts.joined(separator: " | ")
    }

    func inputSourceName(for id: String) -> String {
        inputSourceDisplayName(for: id)
    }

    func mappingConflictSourceName(for conflict: MappingConflict) -> String {
        inputSourceDisplayName(for: conflict.mappedSourceId)
    }

    func mappingConflictReasonText(for conflict: MappingConflict) -> String {
        conflict.reason.rawValue
    }

    func openMappingFix(for deviceKey: KeyboardDeviceKey) {
        if !knownDeviceKeys.contains(deviceKey) {
            knownDeviceKeys.append(deviceKey)
            sortKnownDevices()
        }
        conflictFixTargetDeviceKey = deviceKey
    }

    func refreshInputSourcesNow() {
        refreshInputSourceState(force: true)
    }

    func updateStatus(_ status: InputStatusSnapshot) {
        self.status = status
    }

    private func handleProfileContextChange(actionMessage: String? = nil) {
        refreshProfileState()
        seedKnownDevicesFromMappings()
        refreshMappingConflicts(usingEnabledSources: enabledInputSources)
        refreshActiveTemporaryOverride()

        if let activeKeyboardDevice {
            evaluateSwitch(for: KeyboardDeviceKey(device: activeKeyboardDevice), eventKind: .deviceStabilized)
        }

        if let actionMessage {
            recordAction(actionMessage)
        }
    }

    private func refreshProfileState() {
        profiles = profileManager.profiles
        activeProfileId = profileManager.activeProfileId
    }

    private func configureGlobalHotkeys() {
        globalHotkeyService.setHandler { [weak self] action in
            Task { @MainActor [weak self] in
                self?.handleGlobalHotkey(action)
            }
        }

        applyGlobalHotkeys()
    }

    private func applyGlobalHotkeys() {
        let errors = globalHotkeyService.register(shortcuts: hotkeyAssignments)

        if errors.isEmpty {
            hotkeyRegistrationError = nil
            hotkeyStatusLine = "Global hotkeys active."
            logInfo(category: "hotkey", message: "Registered \(hotkeyAssignments.count) global hotkeys.")
            return
        }

        let sortedErrorMessages = errors
            .sorted { lhs, rhs in
                lhs.key.title.localizedCaseInsensitiveCompare(rhs.key.title) == .orderedAscending
            }
            .map { action, error in
                "\(action.title): \(error)"
            }
        let errorMessage = sortedErrorMessages.joined(separator: " | ")
        hotkeyRegistrationError = errorMessage
        hotkeyStatusLine = "Hotkey registration failed. Fallback to menu/settings actions."
        logError(category: "hotkey", message: errorMessage)
    }

    private func handleGlobalHotkey(_ action: HotkeyAction) {
        switch action {
        case .toggleAutoSwitch:
            setAutoSwitchEnabled(!autoSwitchEnabled)
        case .useCurrentInputSourceForActiveDevice:
            useCurrentInputSourceForActiveDeviceMapping()
        }
    }

    private func loadPersistedHotkeyAssignments() -> [HotkeyAction: KeyCombo] {
        var assignments: [HotkeyAction: KeyCombo] = [:]
        let decoder = JSONDecoder()

        for action in HotkeyAction.allCases {
            if let data = appSettingsStore.data(forKey: action.defaultsStorageKey),
               let decodedCombo = try? decoder.decode(KeyCombo.self, from: data) {
                assignments[action] = decodedCombo
            } else {
                assignments[action] = action.defaultKeyCombo
            }
        }

        return assignments
    }

    private func persistHotkeyCombo(_ combo: KeyCombo, for action: HotkeyAction) {
        let encoder = JSONEncoder()
        if let encodedCombo = try? encoder.encode(combo) {
            appSettingsStore.set(encodedCombo, forKey: action.defaultsStorageKey)
        }
    }

    private static func loadPersistedDeviceFilterRule(from settingsStore: AppSettingsStore) -> DeviceFilterRule {
        guard let data = settingsStore.data(forKey: Self.deviceFilterRuleDefaultsKey),
              let decodedRule = try? JSONDecoder().decode(DeviceFilterRule.self, from: data) else {
            return DeviceFilterRule()
        }

        return decodedRule
    }

    private func persistDeviceFilterRule() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(deviceFilterRule) {
            appSettingsStore.set(data, forKey: Self.deviceFilterRuleDefaultsKey)
        }
    }

    private func serializedBackupData() throws -> Data {
        let snapshot = makeBackupSnapshot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func makeBackupSnapshot() -> AppBackupSnapshot {
        let settings = AppBackupSettings(
            autoSwitchEnabled: autoSwitchEnabled,
            pauseUntil: pauseUntil,
            showNotificationOnSwitch: showNotificationOnSwitch,
            hotkeyAssignments: normalizedHotkeyAssignments(hotkeyAssignments),
            syncViaICloudDriveEnabled: syncViaICloudDriveEnabled
        )

        return AppBackupSnapshot(
            exportedAt: clock.now,
            profiles: profiles,
            activeProfileId: activeProfileId,
            mappingEntries: mappingStore.exportBackupEntries(),
            globalFallbackInputSourceId: globalFallbackInputSourceId,
            deviceFilterRule: deviceFilterRule,
            settings: settings
        )
    }

    private func applyBackupSnapshot(
        _ snapshot: AppBackupSnapshot,
        sourceDescription: String
    ) throws {
        guard snapshot.schemaVersion == AppBackupSnapshot.currentSchemaVersion else {
            throw AppBackupError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }

        isApplyingBackupSnapshot = true
        defer {
            isApplyingBackupSnapshot = false
        }

        profileManager.replaceAllProfiles(snapshot.profiles, activeProfileId: snapshot.activeProfileId)
        mappingStore.replaceAll(with: snapshot.mappingEntries)

        globalFallbackInputSourceId = Self.normalizedInputSourceId(snapshot.globalFallbackInputSourceId)
        appSettingsStore.set(globalFallbackInputSourceId, forKey: Self.globalFallbackInputSourceIdDefaultsKey)

        deviceFilterRule = snapshot.deviceFilterRule
        persistDeviceFilterRule()

        autoSwitchEnabled = snapshot.settings.autoSwitchEnabled
        appSettingsStore.set(autoSwitchEnabled, forKey: Self.autoSwitchEnabledDefaultsKey)

        pauseUntil = snapshot.settings.pauseUntil
        appSettingsStore.set(pauseUntil, forKey: Self.pauseUntilDefaultsKey)

        showNotificationOnSwitch = snapshot.settings.showNotificationOnSwitch
        appSettingsStore.set(showNotificationOnSwitch, forKey: Self.showNotificationOnSwitchDefaultsKey)

        hotkeyAssignments = normalizedHotkeyAssignments(snapshot.settings.hotkeyAssignments)
        for action in HotkeyAction.allCases {
            if let combo = hotkeyAssignments[action] {
                persistHotkeyCombo(combo, for: action)
            }
        }
        applyGlobalHotkeys()

        syncViaICloudDriveEnabled = snapshot.settings.syncViaICloudDriveEnabled
        appSettingsStore.set(syncViaICloudDriveEnabled, forKey: Self.syncViaICloudDriveDefaultsKey)
        isICloudDriveAvailable = iCloudDriveSyncService.isAvailable
        if syncViaICloudDriveEnabled && !isICloudDriveAvailable {
            syncViaICloudDriveEnabled = false
            appSettingsStore.set(false, forKey: Self.syncViaICloudDriveDefaultsKey)
            iCloudDriveSyncHint = "Imported backup enabled iCloud sync, but iCloud Drive is unavailable."
        }

        refreshProfileState()
        seedKnownDevicesFromMappings()
        refreshInputSourceState(force: true)
        refreshMappingConflicts(usingEnabledSources: enabledInputSources)
        refreshActiveTemporaryOverride()
        switchController.reset()
        clearLastError()

        if showNotificationOnSwitch {
            Task { [weak self] in
                await self?.refreshNotificationPermissionStatus(requestIfNeeded: false)
            }
        } else {
            notificationPermissionHint = nil
        }

        if syncViaICloudDriveEnabled {
            iCloudDriveSyncHint = "Synced configuration imported from \(sourceDescription)."
        }

        if isAutoSwitchActive, let activeKeyboardDevice {
            evaluateSwitch(for: KeyboardDeviceKey(device: activeKeyboardDevice), eventKind: .deviceStabilized)
        }
    }

    private func normalizedHotkeyAssignments(
        _ assignments: [HotkeyAction: KeyCombo]
    ) -> [HotkeyAction: KeyCombo] {
        var normalizedAssignments: [HotkeyAction: KeyCombo] = [:]
        for action in HotkeyAction.allCases {
            normalizedAssignments[action] = assignments[action] ?? action.defaultKeyCombo
        }
        return normalizedAssignments
    }

    private func reevaluateForActiveDeviceAfterFilterChange() {
        switchController.reset()
        refreshActiveTemporaryOverride()
        refreshMappingConflicts(usingEnabledSources: enabledInputSources)

        guard let activeKeyboardDevice else {
            return
        }

        evaluateSwitch(
            for: KeyboardDeviceKey(device: activeKeyboardDevice),
            eventKind: .deviceStabilized
        )
    }

    private func seedKnownDevicesFromMappings() {
        knownDeviceKeys = mappingStore.allKnownDeviceKeys()
        sortKnownDevices()
    }

    private func refreshPermissionStatus() {
        let previousStatus = status.permissionStatus
        let newStatus = permissionStatus(for: permissionService.checkInputMonitoring())

        if status.permissionStatus != newStatus {
            status.permissionStatus = newStatus
            let changeMessage = "Permission status changed: \(previousStatus.rawValue) -> \(newStatus.rawValue)."
            if newStatus == .granted {
                logInfo(category: "permission", message: changeMessage)
            } else {
                logWarn(category: "permission", message: changeMessage)
            }
        }

        updateKeyboardMonitoringState()

        if previousStatus == .granted && newStatus != .granted {
            switchController.reset()
            recordFailure("Input Monitoring permission was revoked. Keyboard monitor stopped.")
            logWarn(category: "permission", message: "Input Monitoring permission was revoked during runtime.")
        } else if previousStatus != .granted && newStatus == .granted {
            recordAction("Input Monitoring permission granted.")
            logInfo(category: "permission", message: "Input Monitoring permission granted.")
            clearLastError()
        }
    }

    private func refreshInputSourceState(force: Bool = true) {
        let now = clock.now
        if !force, now.timeIntervalSince(lastInputSourceRefreshAt) < Self.inputSourcePollIntervalSeconds {
            return
        }
        lastInputSourceRefreshAt = now

        let sources = inputSourceService.listEnabledInputSources()
        let allSources = inputSourceService.listAllInputSources()
        let currentId = inputSourceService.currentInputSourceId()
        let currentName = allSources.first(where: { $0.id == currentId })?.name
            ?? sources.first(where: { $0.id == currentId })?.name
        let didEnabledSourcesChange = enabledInputSources != sources

        if didEnabledSourcesChange {
            enabledInputSources = sources
        }

        if allInputSources != allSources {
            allInputSources = allSources
        }

        if currentInputSourceId != currentId {
            currentInputSourceId = currentId
        }

        if currentInputSourceName != currentName {
            currentInputSourceName = currentName
        }

        let displaySource: String
        if let currentName {
            displaySource = currentName
        } else if let currentId {
            displaySource = currentId
        } else {
            displaySource = "none"
        }

        if status.activeInputSource != displaySource {
            status.activeInputSource = displaySource
        }

        if force || didEnabledSourcesChange {
            refreshMappingConflicts(usingEnabledSources: sources)
        }
    }

    private func startPermissionMonitoring() {
        permissionRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    self?.refreshPauseStateIfNeeded()
                    self?.refreshPermissionStatus()
                    self?.refreshInputSourceState(force: false)
                    self?.refreshActiveTemporaryOverride()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func updateKeyboardMonitoringState() {
        guard isInputMonitoringGranted else {
            if hidKeyboardMonitor.isRunning {
                hidKeyboardMonitor.stop()
                debugLog("Stopped HID monitor because permission is not granted.")
                logWarn(category: "hid-monitor", message: "HID monitor stopped because permission is not granted.")
            }
            switchController.reset()
            lastMonitorStartFailure = nil

            if activeKeyboardDevice != nil {
                activeKeyboardDevice = nil
            }

            if status.activeKeyboard != "none" {
                status.activeKeyboard = "none"
            }

            refreshActiveTemporaryOverride()

            return
        }

        let wasRunning = hidKeyboardMonitor.isRunning
        let didStart = hidKeyboardMonitor.start { [weak self] detectedDevice, eventKind in
            Task { @MainActor [weak self] in
                self?.handleDetectedKeyboard(detectedDevice, eventKind: eventKind)
            }
        }

        guard didStart else {
            let failureMessage = hidKeyboardMonitor.lastStartErrorMessage ?? "HID monitor could not start although permission is granted."
            if lastMonitorStartFailure != failureMessage {
                lastMonitorStartFailure = failureMessage
                recordFailure(failureMessage)
            }
            debugLog(failureMessage)
            logError(category: "hid-monitor", message: failureMessage)
            return
        }

        if !wasRunning && hidKeyboardMonitor.isRunning {
            logInfo(category: "hid-monitor", message: "HID monitor started.")
        }

        if let lastMonitorStartFailure, lastAutoSwitchError == lastMonitorStartFailure {
            clearLastError()
        }
        self.lastMonitorStartFailure = nil
    }

    private func handleDetectedKeyboard(_ detectedDevice: ActiveKeyboardDevice, eventKind: KeyboardEventKind) {
        let deviceKey = registerDetectedDevice(detectedDevice)
        let hasChanged = activeKeyboardDevice != detectedDevice

        if hasChanged {
            activeKeyboardDevice = detectedDevice

            let keyboardLine = keyboardDescription(for: detectedDevice)
            if status.activeKeyboard != keyboardLine {
                status.activeKeyboard = keyboardLine
            }

            logInfo(
                category: "active-device",
                message: "Active device changed to \(keyboardLine) (VID \(detectedDevice.vendorId), PID \(detectedDevice.productId))."
            )
        }

        refreshActiveTemporaryOverride(for: deviceKey)
        evaluateSwitch(for: deviceKey, eventKind: eventKind)
    }

    private func registerDetectedDevice(_ device: ActiveKeyboardDevice) -> KeyboardDeviceKey {
        let observedDeviceKey = KeyboardDeviceKey(device: device)
        let canonicalDeviceKey = canonicalDeviceKey(
            for: observedDeviceKey,
            among: knownDeviceKeys
        )
        detectedDevicesByKey[canonicalDeviceKey] = device

        if !knownDeviceKeys.contains(canonicalDeviceKey) {
            knownDeviceKeys.append(canonicalDeviceKey)
            sortKnownDevices()
        }

        return canonicalDeviceKey
    }

    private func evaluateSwitch(for deviceKey: KeyboardDeviceKey, eventKind: KeyboardEventKind) {
        guard isDeviceEnabledForAutoSwitch(deviceKey) else {
            switchController.reset()
            return
        }

        let targetInputSourceId = resolvedTargetInputSourceId(for: deviceKey)

        switchController.evaluateSwitch(
            device: deviceKey,
            currentSource: currentInputSourceId,
            mapping: targetInputSourceId,
            isAutoSwitchActive: isAutoSwitchActive,
            eventKind: eventKind
        ) { [weak self] device, targetInputSourceId, trigger in
            guard let self else {
                return false
            }

            return self.performAutoSwitch(
                for: device,
                targetInputSourceId: targetInputSourceId,
                trigger: trigger
            )
        }
    }

    private func performAutoSwitch(
        for deviceKey: KeyboardDeviceKey,
        targetInputSourceId: String,
        trigger: KeyboardEventKind
    ) -> Bool {
        guard isAutoSwitchActive else {
            return false
        }

        guard let activeKeyboardDevice else {
            return false
        }

        guard isCurrentActiveDeviceRepresented(by: deviceKey, activeKeyboardDevice: activeKeyboardDevice) else {
            return false
        }

        guard targetInputSourceId != currentInputSourceId else {
            return false
        }

        let previousInputSourceId = currentInputSourceId
        let targetSourceName = inputSourceDisplayName(for: targetInputSourceId)
        let deviceName = deviceTitle(for: deviceKey)
        let triggerLabel: String = trigger.isNonModifierKeyDown ? "keyDown" : "stabilized"

        guard attemptSelectInputSource(id: targetInputSourceId, reason: "auto-switch(\(triggerLabel)) for \(deviceName)") else {
            recordFailure("Auto-switch failed for \(deviceName) -> \(targetSourceName).")
            return false
        }

        refreshInputSourceState()
        previousInputSourceIdBeforeLastSwitch = previousInputSourceId
        lastAction = SwitchAction(
            timestamp: clock.now,
            fromInputSourceId: previousInputSourceId,
            toInputSourceId: targetInputSourceId,
            deviceFingerprint: deviceKey.id,
            deviceDisplayName: deviceName
        )
        clearLastError()
        recordAction("Auto-switched \(deviceName) -> \(targetSourceName).")
        sendSwitchNotificationIfNeeded(
            keyboardName: deviceName,
            targetSourceName: targetSourceName
        )
        return true
    }

    private func sortKnownDevices() {
        knownDeviceKeys.sort { lhs, rhs in
            let leftName = deviceTitle(for: lhs)
            let rightName = deviceTitle(for: rhs)
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }
    }

    private func keyboardDescription(for device: ActiveKeyboardDevice) -> String {
        if let productName = device.productName, !productName.isEmpty {
            return productName
        }

        if device.isBuiltIn {
            return "Built-in keyboard"
        }

        return "VID \(device.vendorId), PID \(device.productId)"
    }

    private func inputSourceDisplayName(for id: String) -> String {
        enabledInputSources.first(where: { $0.id == id })?.name
            ?? allInputSources.first(where: { $0.id == id })?.name
            ?? id
    }

    private func resolvedTargetInputSourceId(for deviceKey: KeyboardDeviceKey) -> String? {
        if let temporaryOverrideInputSourceId = resolvedTemporaryOverrideInputSourceId(for: deviceKey) {
            return temporaryOverrideInputSourceId
        }

        if let mappedInputSourceId = resolvedConfiguredInputSourceId(
            for: deviceKey,
            sourceResolver: { [mappingStore] candidateKey in
                mappingStore.getMapping(for: candidateKey)
            }
        ) {
            return mappedInputSourceId
        }

        if let perDeviceFallbackInputSourceId = resolvedConfiguredInputSourceId(
            for: deviceKey,
            sourceResolver: { [mappingStore] candidateKey in
                mappingStore.getPerDeviceFallback(for: candidateKey)
            }
        ) {
            return perDeviceFallbackInputSourceId
        }

        if let globalFallbackInputSourceId,
           inputSourceService.existsEnabledInputSource(id: globalFallbackInputSourceId) {
            return globalFallbackInputSourceId
        }

        return nil
    }

    private func resolvedTemporaryOverrideInputSourceId(for deviceKey: KeyboardDeviceKey) -> String? {
        guard let temporaryOverride = temporaryOverrideStore.temporaryOverride(
            for: deviceKey.primaryIdentifier,
            now: clock.now
        ) else {
            return nil
        }

        guard inputSourceService.existsEnabledInputSource(id: temporaryOverride.inputSourceId) else {
            return nil
        }

        return temporaryOverride.inputSourceId
    }

    private func resolvedConfiguredInputSourceId(
        for observedDeviceKey: KeyboardDeviceKey,
        sourceResolver: (KeyboardDeviceKey) -> String?
    ) -> String? {
        if let exactSourceId = sourceResolver(observedDeviceKey),
           inputSourceService.existsEnabledInputSource(id: exactSourceId) {
            return exactSourceId
        }

        let primaryCandidates = mappingStore
            .allKnownDeviceKeys()
            .filter { $0.matchesPrimary(of: observedDeviceKey.fingerprint) }
            .filter { $0 != observedDeviceKey }

        guard !primaryCandidates.isEmpty else {
            return nil
        }

        let resolvedCandidates: [(key: KeyboardDeviceKey, sourceId: String)] = primaryCandidates.compactMap { candidateKey in
            guard let sourceId = sourceResolver(candidateKey),
                  inputSourceService.existsEnabledInputSource(id: sourceId) else {
                return nil
            }

            return (key: candidateKey, sourceId: sourceId)
        }

        guard !resolvedCandidates.isEmpty else {
            return nil
        }

        if resolvedCandidates.count == 1 {
            return resolvedCandidates[0].sourceId
        }

        if let observedLocationId = observedDeviceKey.locationId,
           let locationMatchedCandidate = resolvedCandidates.first(where: { $0.key.locationId == observedLocationId }) {
            return locationMatchedCandidate.sourceId
        }

        if let locationAgnosticCandidate = resolvedCandidates.first(where: { $0.key.locationId == nil }) {
            return locationAgnosticCandidate.sourceId
        }

        return resolvedCandidates
            .sorted(by: { lhs, rhs in
                lhs.key.id.localizedCaseInsensitiveCompare(rhs.key.id) == .orderedAscending
            })
            .first?
            .sourceId
    }

    private func canonicalDeviceKey(
        for observedDeviceKey: KeyboardDeviceKey,
        among existingKeys: [KeyboardDeviceKey]
    ) -> KeyboardDeviceKey {
        let primaryMatches = existingKeys.filter { $0.matchesPrimary(of: observedDeviceKey.fingerprint) }

        if let exactMatch = primaryMatches.first(where: { $0 == observedDeviceKey }) {
            return exactMatch
        }

        if primaryMatches.count == 1, let existingPrimaryMatch = primaryMatches.first {
            return existingPrimaryMatch
        }

        if let observedLocationId = observedDeviceKey.locationId,
           let locationMatchedKey = primaryMatches.first(where: { $0.locationId == observedLocationId }) {
            return locationMatchedKey
        }

        if let locationAgnosticKey = primaryMatches.first(where: { $0.locationId == nil }) {
            return locationAgnosticKey
        }

        return observedDeviceKey
    }

    private func isCurrentActiveDeviceRepresented(
        by deviceKey: KeyboardDeviceKey,
        activeKeyboardDevice: ActiveKeyboardDevice
    ) -> Bool {
        let activeDeviceKey = KeyboardDeviceKey(device: activeKeyboardDevice)
        if activeDeviceKey == deviceKey {
            return true
        }

        guard activeDeviceKey.matchesPrimary(of: deviceKey.fingerprint) else {
            return false
        }

        let primaryMatches = knownDeviceKeys.filter { $0.matchesPrimary(of: activeDeviceKey.fingerprint) }
        if primaryMatches.count <= 1 {
            return true
        }

        return activeDeviceKey.locationId == deviceKey.locationId
    }

    private func activeDeviceKeyForTemporaryOverride() -> KeyboardDeviceKey? {
        guard let activeKeyboardDevice else {
            return nil
        }

        return canonicalDeviceKey(
            for: KeyboardDeviceKey(device: activeKeyboardDevice),
            among: knownDeviceKeys
        )
    }

    private func refreshActiveTemporaryOverride(for deviceKey: KeyboardDeviceKey? = nil) {
        temporaryOverrideStore.clearExpired(now: clock.now)

        let resolvedDeviceKey = deviceKey ?? activeDeviceKeyForTemporaryOverride()
        guard let resolvedDeviceKey else {
            if activeTemporaryOverride != nil {
                activeTemporaryOverride = nil
            }
            return
        }

        let overrideValue = temporaryOverrideStore.temporaryOverride(
            for: resolvedDeviceKey.primaryIdentifier,
            now: clock.now
        )
        if activeTemporaryOverride != overrideValue {
            activeTemporaryOverride = overrideValue
        }
    }

    private func refreshMappingConflicts(usingEnabledSources sources: [InputSourceInfo]) {
        let enabledIds = Set(sources.map(\.id))
        let conflicts = mappingStore
            .validateMappings(availableEnabledIds: enabledIds)
            .filter { conflict in
                isDeviceEnabledForAutoSwitch(conflict.deviceKey)
            }
        guard mappingConflicts != conflicts else {
            return
        }

        let previousCount = mappingConflicts.count
        mappingConflicts = conflicts

        if let conflictFixTargetDeviceKey,
           !mappingConflicts.contains(where: { $0.deviceKey == conflictFixTargetDeviceKey }) {
            self.conflictFixTargetDeviceKey = nil
        }

        if conflicts.isEmpty, previousCount > 0 {
            logInfo(category: "conflict", message: "All mapping conflicts resolved.")
        } else if !conflicts.isEmpty {
            logWarn(category: "conflict", message: "Detected \(conflicts.count) mapping conflict(s).")
        }
    }

    private func attemptSelectInputSource(id: String, reason: String) -> Bool {
        let sourceName = inputSourceDisplayName(for: id)
        logInfo(category: "input-source", message: "Attempting \(reason): \(sourceName) (\(id)).")

        let didSelect = inputSourceService.selectInputSource(id: id)
        if didSelect {
            logInfo(category: "input-source", message: "Selection succeeded for \(sourceName) (\(id)).")
        } else {
            logError(category: "input-source", message: "Selection failed for \(sourceName) (\(id)).")
        }

        return didSelect
    }

    private func refreshNotificationPermissionStatus(requestIfNeeded: Bool) async {
        guard showNotificationOnSwitch else {
            notificationPermissionHint = nil
            return
        }

        let status: UNAuthorizationStatus
        if requestIfNeeded {
            status = await notificationService.requestNotificationPermissionIfNeeded()
        } else {
            status = await notificationService.notificationAuthorizationStatus()
        }

        guard showNotificationOnSwitch else {
            notificationPermissionHint = nil
            return
        }

        switch status {
        case .denied:
            notificationPermissionHint = "Notifications denied. Enable notifications for InputPilot in System Settings."
            logWarn(category: "notification", message: "Notifications are denied.")
        case .authorized, .provisional:
            notificationPermissionHint = nil
        case .notDetermined:
            notificationPermissionHint = "Notification permission not granted yet."
        @unknown default:
            notificationPermissionHint = "Notification permission status is unknown."
        }
    }

    private func sendSwitchNotificationIfNeeded(
        keyboardName: String,
        targetSourceName: String
    ) {
        guard showNotificationOnSwitch else {
            return
        }

        Task { [weak self] in
            guard let self else {
                return
            }

            let status = await self.notificationService.notificationAuthorizationStatus()
            if !Self.isNotificationAuthorizationGranted(status) {
                await self.refreshNotificationPermissionStatus(requestIfNeeded: false)
                return
            }

            let didSend = await self.notificationService.sendNotification(
                title: "Input source switched",
                body: "\(keyboardName) → \(targetSourceName)"
            )
            if didSend {
                self.logInfo(
                    category: "notification",
                    message: "Posted switch notification for \(keyboardName) -> \(targetSourceName)."
                )
            } else {
                self.logWarn(
                    category: "notification",
                    message: "Failed to post switch notification for \(keyboardName)."
                )
            }
        }
    }

    private static func isNotificationAuthorizationGranted(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func scheduleICloudSyncIfNeeded() {
        guard syncViaICloudDriveEnabled else {
            return
        }

        guard !isApplyingBackupSnapshot else {
            return
        }

        isICloudDriveAvailable = iCloudDriveSyncService.isAvailable
        guard isICloudDriveAvailable else {
            iCloudDriveSyncHint = "iCloud Drive is unavailable."
            return
        }

        iCloudSyncTask?.cancel()
        iCloudSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            await MainActor.run {
                self?.syncToICloudDriveNow()
            }
        }
    }

    private func bootstrapICloudSyncAfterEnable() {
        do {
            if let data = try iCloudDriveSyncService.loadBackupData(), !data.isEmpty {
                let snapshot = try AppBackupMigrator.decodeSnapshot(from: data)
                try applyBackupSnapshot(snapshot, sourceDescription: "iCloud Drive")
                lastICloudSyncedBackupData = data
                backupErrorMessage = nil
                backupStatusLine = "Imported backup from iCloud Drive."
                iCloudDriveSyncHint = "Loaded backup from iCloud Drive."
                return
            }

            scheduleICloudSyncIfNeeded()
        } catch {
            let message = "iCloud backup load failed: \(error.localizedDescription)"
            backupErrorMessage = message
            backupStatusLine = "iCloud import failed."
            iCloudDriveSyncHint = message
        }
    }

    private func syncToICloudDriveNow() {
        guard syncViaICloudDriveEnabled else {
            return
        }

        do {
            let data = try serializedBackupData()
            if data == lastICloudSyncedBackupData {
                return
            }

            try iCloudDriveSyncService.saveBackupData(data)
            lastICloudSyncedBackupData = data
            iCloudDriveSyncHint = "Last iCloud sync: \(formattedTime(clock.now))."
            backupErrorMessage = nil
        } catch {
            iCloudDriveSyncHint = "iCloud sync failed: \(error.localizedDescription)"
        }
    }

    private func logInfo(category: String, message: String) {
        debugLogService.logInfo(category: category, message: message)
        debugLogEntries = debugLogService.entries
    }

    private func logWarn(category: String, message: String) {
        debugLogService.logWarn(category: category, message: message)
        debugLogEntries = debugLogService.entries
    }

    private func logError(category: String, message: String) {
        debugLogService.logError(category: category, message: message)
        debugLogEntries = debugLogService.entries
    }

    private func recordAction(_ message: String) {
        lastAutoSwitchAction = message
        debugLog(message)
        scheduleICloudSyncIfNeeded()
    }

    private func recordFailure(_ message: String) {
        lastAutoSwitchAction = message
        lastAutoSwitchError = message
        debugLog("ERROR: \(message)")
    }

    private func clearLastError() {
        if lastAutoSwitchError != nil {
            lastAutoSwitchError = nil
        }
    }

    private func permissionStatus(for accessType: IOHIDAccessType) -> PermissionStatus {
        switch accessType {
        case kIOHIDAccessTypeGranted:
            return .granted
        case kIOHIDAccessTypeDenied:
            return .denied
        default:
            return .unknown
        }
    }

    private func refreshPauseStateIfNeeded() {
        guard let pauseUntil else {
            return
        }

        guard pauseUntil < clock.now else {
            return
        }

        self.pauseUntil = nil
        appSettingsStore.set(Optional<Date>.none, forKey: Self.pauseUntilDefaultsKey)
        recordAction("Pause expired. Auto-switch active.")

        if isAutoSwitchActive, let activeKeyboardDevice {
            evaluateSwitch(for: KeyboardDeviceKey(device: activeKeyboardDevice), eventKind: .deviceStabilized)
        }
    }

    private func formattedTime(_ date: Date) -> String {
        Self.pauseTimeFormatter.string(from: date)
    }

    private func endOfToday(from date: Date) -> Date? {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: date
        )
    }

    private static let pauseTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static func normalizedInputSourceId(_ inputSourceId: String?) -> String? {
        guard let inputSourceId, !inputSourceId.isEmpty else {
            return nil
        }

        return inputSourceId
    }

    private func debugLog(_ message: String) {
#if DEBUG
        logger.debug("\(message, privacy: .public)")
#endif
    }
}
