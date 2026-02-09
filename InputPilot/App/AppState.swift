import Foundation
import Combine
import AppKit
import IOKit.hid
#if DEBUG
import OSLog
#endif

@MainActor
final class AppState: ObservableObject {
    private static let autoSwitchPausedDefaultsKey = "autoSwitchPaused"

    @Published private(set) var status = InputStatusSnapshot.placeholder
    @Published private(set) var activeKeyboardDevice: ActiveKeyboardDevice?
    @Published private(set) var currentInputSourceId: String?
    @Published private(set) var currentInputSourceName: String?
    @Published private(set) var enabledInputSources: [InputSourceInfo] = []
    @Published private(set) var knownDeviceKeys: [KeyboardDeviceKey] = []
    @Published private(set) var isAutoSwitchPaused: Bool
    @Published private(set) var lastAutoSwitchAction = "No auto-switch action yet."
    @Published private(set) var lastAutoSwitchError: String?

    private let permissionService: PermissionService
    private let hidKeyboardMonitor: HIDKeyboardMonitor
    private let inputSourceService: InputSourceService
    private let mappingStore: MappingStore
    private let appSettingsStore: AppSettingsStore

    private var detectedDevicesByKey: [KeyboardDeviceKey: ActiveKeyboardDevice] = [:]
    private var permissionRefreshTask: Task<Void, Never>?
    private var autoSwitchTask: Task<Void, Never>?
    private var lastMonitorStartFailure: String?

#if DEBUG
    private let logger = Logger(subsystem: "InputPilot", category: "AppState")
#endif

    init(
        permissionService: PermissionService,
        hidKeyboardMonitor: HIDKeyboardMonitor,
        inputSourceService: InputSourceService,
        mappingStore: MappingStore,
        appSettingsStore: AppSettingsStore
    ) {
        self.permissionService = permissionService
        self.hidKeyboardMonitor = hidKeyboardMonitor
        self.inputSourceService = inputSourceService
        self.mappingStore = mappingStore
        self.appSettingsStore = appSettingsStore
        self.isAutoSwitchPaused = appSettingsStore.bool(
            forKey: Self.autoSwitchPausedDefaultsKey,
            default: false
        )

        seedKnownDevicesFromMappings()
        refreshPermissionStatus()
        refreshInputSourceState()
        startPermissionMonitoring()

        if isAutoSwitchPaused {
            recordAction("Auto-switch is currently paused.")
        }
    }

    convenience init() {
        self.init(
            permissionService: PermissionService(),
            hidKeyboardMonitor: HIDKeyboardMonitor(),
            inputSourceService: InputSourceService(),
            mappingStore: MappingStore(),
            appSettingsStore: AppSettingsStore()
        )
    }

    deinit {
        permissionRefreshTask?.cancel()
        autoSwitchTask?.cancel()
    }

    var permissionLine: String {
        "Permission: \(status.permissionStatus.rawValue)"
    }

    var activeKeyboardLine: String {
        "Active keyboard: \(status.activeKeyboard)"
    }

    var activeInputSourceLine: String {
        "Active input source: \(status.activeInputSource)"
    }

    var isInputMonitoringGranted: Bool {
        status.permissionStatus == .granted
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

    var selectableInputSources: [InputSourceInfo] {
        enabledInputSources.filter { $0.isSelectable }
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

    func setAutoSwitchPaused(_ paused: Bool) {
        guard isAutoSwitchPaused != paused else {
            return
        }

        isAutoSwitchPaused = paused
        appSettingsStore.set(paused, forKey: Self.autoSwitchPausedDefaultsKey)

        if paused {
            autoSwitchTask?.cancel()
            recordAction("Auto-switch paused.")
            return
        }

        recordAction("Auto-switch resumed.")

        if let activeKeyboardDevice {
            scheduleAutoSwitch(for: KeyboardDeviceKey(device: activeKeyboardDevice))
        }
    }

    func selectInputSource(_ id: String) {
        let sourceName = inputSourceDisplayName(for: id)

        guard inputSourceService.selectInputSource(id: id) else {
            recordFailure("Failed to select input source: \(sourceName).")
            return
        }

        refreshInputSourceState()
        clearLastError()
        recordAction("Selected input source: \(sourceName).")
    }

    func mappedInputSourceId(for deviceKey: KeyboardDeviceKey) -> String? {
        mappingStore.getMapping(for: deviceKey)
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

        if activeKeyboardDevice.map({ KeyboardDeviceKey(device: $0) }) == deviceKey {
            scheduleAutoSwitch(for: deviceKey)
        }
    }

    func forgetDevice(_ deviceKey: KeyboardDeviceKey) {
        mappingStore.removeMapping(deviceKey: deviceKey)
        detectedDevicesByKey.removeValue(forKey: deviceKey)
        knownDeviceKeys.removeAll { $0 == deviceKey }
        recordAction("Forgot device: \(deviceTitle(for: deviceKey)).")
        clearLastError()
    }

    func deviceTitle(for deviceKey: KeyboardDeviceKey) -> String {
        if let productName = detectedDevicesByKey[deviceKey]?.productName, !productName.isEmpty {
            return productName
        }

        return "Keyboard VID \(deviceKey.vendorId), PID \(deviceKey.productId)"
    }

    func deviceSubtitle(for deviceKey: KeyboardDeviceKey) -> String {
        var parts = ["VID \(deviceKey.vendorId)", "PID \(deviceKey.productId)"]

        if let transport = deviceKey.transport, !transport.isEmpty {
            parts.append(transport)
        }

        if let locationId = deviceKey.locationId {
            parts.append("Location \(locationId)")
        }

        return parts.joined(separator: " | ")
    }

    func updateStatus(_ status: InputStatusSnapshot) {
        self.status = status
    }

    private func seedKnownDevicesFromMappings() {
        knownDeviceKeys = Array(mappingStore.allMappings().keys)
        sortKnownDevices()
    }

    private func refreshPermissionStatus() {
        let previousStatus = status.permissionStatus
        let newStatus = permissionStatus(for: permissionService.checkInputMonitoring())

        if status.permissionStatus != newStatus {
            status.permissionStatus = newStatus
        }

        updateKeyboardMonitoringState()

        if previousStatus == .granted && newStatus != .granted {
            autoSwitchTask?.cancel()
            recordFailure("Input Monitoring permission was revoked. Keyboard monitor stopped.")
        } else if previousStatus != .granted && newStatus == .granted {
            recordAction("Input Monitoring permission granted.")
            clearLastError()
        }
    }

    private func refreshInputSourceState() {
        let sources = inputSourceService.listEnabledInputSources()
        let currentId = inputSourceService.currentInputSourceId()
        let currentName = sources.first(where: { $0.id == currentId })?.name

        if enabledInputSources != sources {
            enabledInputSources = sources
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
    }

    private func startPermissionMonitoring() {
        permissionRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    self?.refreshPermissionStatus()
                    self?.refreshInputSourceState()
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
            }
            lastMonitorStartFailure = nil

            if activeKeyboardDevice != nil {
                activeKeyboardDevice = nil
            }

            if status.activeKeyboard != "none" {
                status.activeKeyboard = "none"
            }

            return
        }

        let didStart = hidKeyboardMonitor.start { [weak self] detectedDevice in
            Task { @MainActor [weak self] in
                self?.handleDetectedKeyboard(detectedDevice)
            }
        }

        guard didStart else {
            let failureMessage = hidKeyboardMonitor.lastStartErrorMessage ?? "HID monitor could not start although permission is granted."
            if lastMonitorStartFailure != failureMessage {
                lastMonitorStartFailure = failureMessage
                recordFailure(failureMessage)
            }
            debugLog(failureMessage)
            return
        }

        if let lastMonitorStartFailure, lastAutoSwitchError == lastMonitorStartFailure {
            clearLastError()
        }
        self.lastMonitorStartFailure = nil
    }

    private func handleDetectedKeyboard(_ detectedDevice: ActiveKeyboardDevice) {
        let deviceKey = registerDetectedDevice(detectedDevice)
        let hasChanged = activeKeyboardDevice != detectedDevice

        guard hasChanged else {
            return
        }

        activeKeyboardDevice = detectedDevice

        let keyboardLine = keyboardDescription(for: detectedDevice)
        if status.activeKeyboard != keyboardLine {
            status.activeKeyboard = keyboardLine
        }

        scheduleAutoSwitch(for: deviceKey)
    }

    private func registerDetectedDevice(_ device: ActiveKeyboardDevice) -> KeyboardDeviceKey {
        let deviceKey = KeyboardDeviceKey(device: device)
        detectedDevicesByKey[deviceKey] = device

        if !knownDeviceKeys.contains(deviceKey) {
            knownDeviceKeys.append(deviceKey)
            sortKnownDevices()
        }

        return deviceKey
    }

    private func scheduleAutoSwitch(for deviceKey: KeyboardDeviceKey) {
        guard !isAutoSwitchPaused else {
            return
        }

        autoSwitchTask?.cancel()

        autoSwitchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.applyMappingIfNeeded(for: deviceKey)
            }
        }
    }

    private func applyMappingIfNeeded(for deviceKey: KeyboardDeviceKey) {
        guard !isAutoSwitchPaused else {
            return
        }

        guard let activeKeyboardDevice else {
            return
        }

        guard KeyboardDeviceKey(device: activeKeyboardDevice) == deviceKey else {
            return
        }

        guard let mappedInputSourceId = mappingStore.getMapping(for: deviceKey) else {
            return
        }

        guard mappedInputSourceId != currentInputSourceId else {
            return
        }

        let targetSourceName = inputSourceDisplayName(for: mappedInputSourceId)
        let deviceName = deviceTitle(for: deviceKey)

        guard inputSourceService.selectInputSource(id: mappedInputSourceId) else {
            recordFailure("Auto-switch failed for \(deviceName) -> \(targetSourceName).")
            return
        }

        refreshInputSourceState()
        clearLastError()
        recordAction("Auto-switched \(deviceName) -> \(targetSourceName).")
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

        return "VID \(device.vendorId), PID \(device.productId)"
    }

    private func inputSourceDisplayName(for id: String) -> String {
        enabledInputSources.first(where: { $0.id == id })?.name ?? id
    }

    private func recordAction(_ message: String) {
        lastAutoSwitchAction = message
        debugLog(message)
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

    private func debugLog(_ message: String) {
#if DEBUG
        logger.debug("\(message, privacy: .public)")
#endif
    }
}
