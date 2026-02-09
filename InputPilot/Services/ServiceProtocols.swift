import Foundation
import IOKit.hid

protocol PermissionServicing: AnyObject {
    func checkInputMonitoring() -> IOHIDAccessType
    func requestInputMonitoring() -> Bool
    var isGranted: Bool { get }
}

protocol HIDKeyboardMonitoring: AnyObject {
    @discardableResult
    func start(onEvent: @escaping (ActiveKeyboardDevice, KeyboardEventKind) -> Void) -> Bool
    func stop()
    var isRunning: Bool { get }
    var lastStartErrorMessage: String? { get }
}

protocol InputSourceServicing: AnyObject {
    func listEnabledInputSources() -> [InputSourceInfo]
    func listAllInputSources() -> [InputSourceInfo]
    func existsEnabledInputSource(id: String) -> Bool
    func currentInputSourceId() -> String?
    func selectInputSource(id: String) -> Bool
}

@MainActor
protocol ProfileManaging: AnyObject {
    var profiles: [Profile] { get }
    var activeProfileId: String { get }
    @discardableResult
    func createProfile(name: String) -> Profile
    func renameProfile(id: String, name: String)
    @discardableResult
    func deleteProfile(id: String) -> Bool
    func setActiveProfile(id: String)
}

@MainActor
protocol MappingStoring: AnyObject {
    func getMapping(for deviceKey: KeyboardDeviceKey) -> String?
    func setMapping(deviceKey: KeyboardDeviceKey, inputSourceId: String)
    func getPerDeviceFallback(for deviceKey: KeyboardDeviceKey) -> String?
    func setPerDeviceFallback(deviceKey: KeyboardDeviceKey, inputSourceId: String?)
    func removeMapping(deviceKey: KeyboardDeviceKey)
    func removeProfileData(profileId: String)
    func allMappings() -> [KeyboardDeviceKey: String]
    func allKnownDeviceKeys() -> [KeyboardDeviceKey]
    func validateMappings(availableEnabledIds: Set<String>) -> [MappingConflict]
}

protocol ClockProviding {
    var now: Date { get }
    func sleep(for duration: Duration) async throws
}

protocol DebugLogServicing: AnyObject {
    var entries: [LogEntry] { get }
    func logInfo(category: String, message: String)
    func logWarn(category: String, message: String)
    func logError(category: String, message: String)
    func export() -> String
}

protocol GlobalHotkeyServicing: AnyObject {
    func setHandler(_ handler: @escaping (HotkeyAction) -> Void)
    func register(shortcuts: [HotkeyAction: KeyCombo]) -> [HotkeyAction: String]
    func unregisterAll()
}

@MainActor
protocol TemporaryOverrideStoring: AnyObject {
    func setOverride(
        deviceFingerprintKey: String,
        inputSourceId: String,
        expiresAt: Date?,
        persistAcrossLaunch: Bool
    )
    func temporaryOverride(for deviceFingerprintKey: String, now: Date) -> TemporaryOverride?
    func clearOverride(for deviceFingerprintKey: String)
    func clearExpired(now: Date)
}

struct SystemClock: ClockProviding {
    var now: Date {
        Date()
    }

    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
