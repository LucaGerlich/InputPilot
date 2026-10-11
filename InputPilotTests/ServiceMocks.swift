import Foundation
import IOKit.hid
@testable import InputPilot

@MainActor
final class MockPermissionService: PermissionServicing {
    var accessType: IOHIDAccessType
    private(set) var requestCount = 0

    init(accessType: IOHIDAccessType) {
        self.accessType = accessType
    }

    func checkInputMonitoring() -> IOHIDAccessType {
        accessType
    }

    func requestInputMonitoring() -> Bool {
        requestCount += 1
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

    var onDeviceRemoved: ((ActiveKeyboardDevice) -> Void)?
    var connected: [ActiveKeyboardDevice] = []
    var allowsPartialOpen = false
    /// Models IOHIDManagerOpen returning kIOReturnExclusiveAccess because
    /// another app (Karabiner-Elements) holds one of the keyboards.
    var exclusiveAccessMessage: String?
    var startResult = true
    var isRunning = false
    var lastStartErrorMessage: String?
    private(set) var startCallCount = 0

    @discardableResult
    func start(onEvent: @escaping (ActiveKeyboardDevice, KeyboardEventKind) -> Void) -> Bool {
        self.onEvent = onEvent
        startCallCount += 1

        if let exclusiveAccessMessage {
            lastStartErrorMessage = exclusiveAccessMessage
            isRunning = allowsPartialOpen
            return allowsPartialOpen
        }

        if startResult {
            isRunning = true
            lastStartErrorMessage = nil
        }

        return startResult
    }

    func stop() {
        isRunning = false
    }

    func connectedDevices() -> [ActiveKeyboardDevice] {
        connected
    }

    func emit(_ device: ActiveKeyboardDevice, kind: KeyboardEventKind = .keyDown(isModifier: false)) {
        onEvent?(device, kind)
    }

    func emitRemoval(_ device: ActiveKeyboardDevice) {
        onDeviceRemoved?(device)
    }
}

@MainActor
final class MockInputSourceService: InputSourceServicing {
    var enabledSources: [InputSourceInfo] = []
    var allSources: [InputSourceInfo] = []
    var currentInputSourceIdValue: String?
    var selectInputSourceResult = true
    /// False models TIS reporting success without the source actually
    /// changing, a known macOS behaviour with some CJK input methods.
    var selectTakesEffect = true
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

        if selectInputSourceResult, selectTakesEffect {
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
        mappings.compactMap { deviceKey, mappedId -> MappingConflict? in
            guard !availableEnabledIds.contains(mappedId) else {
                return nil
            }

            return MappingConflict(
                deviceKey: deviceKey,
                mappedSourceId: mappedId,
                reason: .missingOrDisabled
            )
        }
        // Match the real MappingStore's deterministic ordering.
        .sorted { lhs, rhs in
            if lhs.deviceKey.id == rhs.deviceKey.id {
                return lhs.mappedSourceId < rhs.mappedSourceId
            }

            return lhs.deviceKey.id < rhs.deviceKey.id
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

/// Holds every `sleep` until the test releases it, so a test can act inside
/// the debounce window - between a switch being scheduled and carried out.
@MainActor
final class GatedClock: ClockProviding {
    var now = Date()
    private var sleepers: [CheckedContinuation<Void, Never>] = []

    var hasSleepers: Bool {
        !sleepers.isEmpty
    }

    func sleep(for duration: Duration) async throws {
        await withCheckedContinuation { continuation in
            sleepers.append(continuation)
        }
    }

    func releaseSleepers() {
        let pending = sleepers
        sleepers = []
        pending.forEach { $0.resume() }
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
