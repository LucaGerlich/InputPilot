import Foundation
import IOKit.hid
import UserNotifications
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
final class MockProfileManager: ProfileManaging {
    private(set) var profiles: [Profile]
    private(set) var activeProfileId: String

    init(
        profiles: [Profile]? = nil,
        activeProfileId: String? = nil
    ) {
        let resolvedProfiles = profiles ?? Profile.defaultProfiles
        let resolvedActiveProfileId = activeProfileId ?? Profile.defaultProfileId

        self.profiles = resolvedProfiles
        if resolvedProfiles.contains(where: { $0.id == resolvedActiveProfileId }) {
            self.activeProfileId = resolvedActiveProfileId
        } else {
            self.activeProfileId = resolvedProfiles.first?.id ?? Profile.defaultProfileId
        }
    }

    @discardableResult
    func createProfile(name: String) -> Profile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileName = trimmedName.isEmpty ? "Profile" : trimmedName
        let profile = Profile(id: UUID().uuidString.lowercased(), name: profileName, createdAt: Date())
        profiles.append(profile)
        return profile
    }

    func renameProfile(id: String, name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        profiles[index].name = trimmedName
    }

    @discardableResult
    func deleteProfile(id: String) -> Bool {
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else {
            return false
        }

        profiles.remove(at: index)
        if activeProfileId == id {
            activeProfileId = profiles.first?.id ?? Profile.defaultProfileId
        }
        return true
    }

    func setActiveProfile(id: String) {
        guard profiles.contains(where: { $0.id == id }) else {
            return
        }

        activeProfileId = id
    }

    func replaceAllProfiles(_ profiles: [Profile], activeProfileId: String?) {
        let resolvedProfiles = profiles.isEmpty ? Profile.defaultProfiles : profiles
        self.profiles = resolvedProfiles

        if let activeProfileId,
           resolvedProfiles.contains(where: { $0.id == activeProfileId }) {
            self.activeProfileId = activeProfileId
        } else {
            self.activeProfileId = resolvedProfiles.first?.id ?? Profile.defaultProfileId
        }
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

    func removeProfileData(profileId: String) {
        _ = profileId
        mappings.removeAll()
        perDeviceFallbacks.removeAll()
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

    func exportBackupEntries() -> [MappingBackupEntry] {
        let profileId = Profile.defaultProfileId

        let mappingEntries = mappings.map { deviceKey, inputSourceId in
            MappingBackupEntry(
                profileId: profileId,
                deviceKey: deviceKey,
                inputSourceId: inputSourceId,
                perDeviceFallbackInputSourceId: perDeviceFallbacks[deviceKey]
            )
        }

        let fallbackOnlyEntries = perDeviceFallbacks
            .filter { mappings[$0.key] == nil }
            .map { deviceKey, fallbackId in
                MappingBackupEntry(
                    profileId: profileId,
                    deviceKey: deviceKey,
                    inputSourceId: nil,
                    perDeviceFallbackInputSourceId: fallbackId
                )
            }

        return (mappingEntries + fallbackOnlyEntries)
            .sorted { lhs, rhs in
                lhs.deviceKey.id < rhs.deviceKey.id
            }
    }

    func replaceAll(with entries: [MappingBackupEntry]) {
        mappings.removeAll()
        perDeviceFallbacks.removeAll()

        for entry in entries {
            if let inputSourceId = entry.inputSourceId {
                mappings[entry.deviceKey] = inputSourceId
            }
            if let fallbackId = entry.perDeviceFallbackInputSourceId {
                perDeviceFallbacks[entry.deviceKey] = fallbackId
            }
        }
    }
}

@MainActor
final class MockTemporaryOverrideStore: TemporaryOverrideStoring {
    var overridesByFingerprintKey: [String: TemporaryOverride] = [:]
    private(set) var persistedKeys: Set<String> = []

    func setOverride(
        deviceFingerprintKey: String,
        inputSourceId: String,
        expiresAt: Date?,
        persistAcrossLaunch: Bool
    ) {
        let overrideValue = TemporaryOverride(
            deviceFingerprintKey: deviceFingerprintKey,
            inputSourceId: inputSourceId,
            expiresAt: expiresAt
        )
        overridesByFingerprintKey[deviceFingerprintKey] = overrideValue

        if persistAcrossLaunch, expiresAt != nil {
            persistedKeys.insert(deviceFingerprintKey)
        } else {
            persistedKeys.remove(deviceFingerprintKey)
        }
    }

    func temporaryOverride(for deviceFingerprintKey: String, now: Date) -> TemporaryOverride? {
        clearExpired(now: now)
        return overridesByFingerprintKey[deviceFingerprintKey]
    }

    func clearOverride(for deviceFingerprintKey: String) {
        overridesByFingerprintKey.removeValue(forKey: deviceFingerprintKey)
        persistedKeys.remove(deviceFingerprintKey)
    }

    func clearExpired(now: Date) {
        let expiredKeys = overridesByFingerprintKey
            .filter { _, overrideValue in
                overrideValue.isExpired(at: now)
            }
            .map(\.key)
        for key in expiredKeys {
            overridesByFingerprintKey.removeValue(forKey: key)
            persistedKeys.remove(key)
        }
    }
}

@MainActor
final class MockNotificationService: NotificationServicing {
    struct SentNotification: Equatable {
        let title: String
        let body: String
    }

    var authorizationStatus: UNAuthorizationStatus = .authorized
    var requestAuthorizationResultStatus: UNAuthorizationStatus = .authorized
    var sendResult = true
    private(set) var requestPermissionCallCount = 0
    private(set) var sentNotifications: [SentNotification] = []

    func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }

    func requestNotificationPermissionIfNeeded() async -> UNAuthorizationStatus {
        requestPermissionCallCount += 1
        if authorizationStatus == .notDetermined {
            authorizationStatus = requestAuthorizationResultStatus
        }
        return authorizationStatus
    }

    func sendNotification(title: String, body: String) async -> Bool {
        sentNotifications.append(.init(title: title, body: body))
        return sendResult
    }
}

@MainActor
final class MockICloudDriveSyncService: ICloudDriveSyncServicing {
    var available = true
    var storedBackupData: Data?
    var saveError: Error?
    var loadError: Error?

    var isAvailable: Bool {
        available
    }

    func loadBackupData() throws -> Data? {
        if let loadError {
            throw loadError
        }
        return storedBackupData
    }

    func saveBackupData(_ data: Data) throws {
        if let saveError {
            throw saveError
        }
        storedBackupData = data
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
