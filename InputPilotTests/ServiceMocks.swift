import Foundation
import IOKit.hid
@testable import InputPilot

@MainActor
final class MockPermissionService: PermissionServicing {
    var accessType: IOHIDAccessType

    init(accessType: IOHIDAccessType) {
        self.accessType = accessType
    }

    func checkInputMonitoring() -> IOHIDAccessType {
        accessType
    }

    func requestInputMonitoring() -> Bool {
        accessType = kIOHIDAccessTypeGranted
        return true
    }

    var isGranted: Bool {
        accessType == kIOHIDAccessTypeGranted
    }
}

@MainActor
final class MockHIDKeyboardMonitor: HIDKeyboardMonitoring {
    private var onEvent: ((ActiveKeyboardDevice, KeyboardEventKind) -> Void)?

    var startResult = true
    var isRunning = false
    var lastStartErrorMessage: String?

    @discardableResult
    func start(onEvent: @escaping (ActiveKeyboardDevice, KeyboardEventKind) -> Void) -> Bool {
        self.onEvent = onEvent

        if startResult {
            isRunning = true
            lastStartErrorMessage = nil
        }

        return startResult
    }

    func stop() {
        isRunning = false
    }

    func emit(_ device: ActiveKeyboardDevice, kind: KeyboardEventKind = .keyDown(isModifier: false)) {
        onEvent?(device, kind)
    }
}

@MainActor
final class MockInputSourceService: InputSourceServicing {
    var enabledSources: [InputSourceInfo] = []
    var allSources: [InputSourceInfo] = []
    var currentInputSourceIdValue: String?
    var selectInputSourceResult = true
    private(set) var selectCalls: [String] = []

    func listEnabledInputSources() -> [InputSourceInfo] {
        enabledSources
    }

    func listAllInputSources() -> [InputSourceInfo] {
        if allSources.isEmpty {
            return enabledSources
        }

        return allSources
    }

    func existsEnabledInputSource(id: String) -> Bool {
        enabledSources.contains(where: { $0.id == id })
    }

    func currentInputSourceId() -> String? {
        currentInputSourceIdValue
    }

    func selectInputSource(id: String) -> Bool {
        selectCalls.append(id)

        if selectInputSourceResult {
            currentInputSourceIdValue = id
        }

        return selectInputSourceResult
    }
}

@MainActor
final class MockMappingStore: MappingStoring {
    var mappings: [KeyboardDeviceKey: String] = [:]
    var perDeviceFallbacks: [KeyboardDeviceKey: String] = [:]

    func getMapping(for deviceKey: KeyboardDeviceKey) -> String? {
        mappings[deviceKey]
    }

    func setMapping(deviceKey: KeyboardDeviceKey, inputSourceId: String) {
        mappings[deviceKey] = inputSourceId
    }

    func getPerDeviceFallback(for deviceKey: KeyboardDeviceKey) -> String? {
        perDeviceFallbacks[deviceKey]
    }

    func setPerDeviceFallback(deviceKey: KeyboardDeviceKey, inputSourceId: String?) {
        if let inputSourceId, !inputSourceId.isEmpty {
            perDeviceFallbacks[deviceKey] = inputSourceId
        } else {
            perDeviceFallbacks.removeValue(forKey: deviceKey)
        }
    }

    func removeMapping(deviceKey: KeyboardDeviceKey) {
        mappings.removeValue(forKey: deviceKey)
    }

    func allMappings() -> [KeyboardDeviceKey: String] {
        mappings
    }

    func allKnownDeviceKeys() -> [KeyboardDeviceKey] {
        let keys = Set(mappings.keys).union(perDeviceFallbacks.keys)
        return Array(keys)
    }

    func validateMappings(availableEnabledIds: Set<String>) -> [MappingConflict] {
        mappings.compactMap { deviceKey, mappedId in
            guard !availableEnabledIds.contains(mappedId) else {
                return nil
            }

            return MappingConflict(
                deviceKey: deviceKey,
                mappedSourceId: mappedId,
                reason: .missingOrDisabled
            )
        }
    }
}

@MainActor
final class ImmediateClock: ClockProviding {
    var now = Date()
    private(set) var sleptDurations: [Duration] = []

    func sleep(for duration: Duration) async throws {
        sleptDurations.append(duration)
        now = now.addingTimeInterval(Self.timeInterval(for: duration))
    }

    func advance(by duration: Duration) {
        now = now.addingTimeInterval(Self.timeInterval(for: duration))
    }

    private static func timeInterval(for duration: Duration) -> TimeInterval {
        let components = duration.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return seconds + attoseconds
    }
}
