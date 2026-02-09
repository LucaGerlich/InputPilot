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

protocol MappingStoring: AnyObject {
    func getMapping(for deviceKey: KeyboardDeviceKey) -> String?
    func setMapping(deviceKey: KeyboardDeviceKey, inputSourceId: String)
    func getPerDeviceFallback(for deviceKey: KeyboardDeviceKey) -> String?
    func setPerDeviceFallback(deviceKey: KeyboardDeviceKey, inputSourceId: String?)
    func removeMapping(deviceKey: KeyboardDeviceKey)
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

struct SystemClock: ClockProviding {
    var now: Date {
        Date()
    }

    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
