import Foundation

@MainActor
final class MappingStore: MappingStoring {
    private struct StoredMapping: Codable {
        let profileId: String
        let deviceKey: KeyboardDeviceKey
        let inputSourceId: String?
        let perDeviceFallbackInputSourceId: String?
    }

    private struct LegacyProfilelessStoredMapping: Codable {
        let deviceKey: KeyboardDeviceKey
        let inputSourceId: String?
        let perDeviceFallbackInputSourceId: String?
    }

    private struct LegacyFlatStoredMapping: Codable {
        let vendorId: Int
        let productId: Int
        let transport: String?
        let locationId: Int?
        let isBuiltIn: Bool?
        let productName: String?
        let inputSourceId: String?
        let perDeviceFallbackInputSourceId: String?
    }

    private struct DeviceConfiguration {
        var mappingInputSourceId: String?
        var perDeviceFallbackInputSourceId: String?
    }

    private typealias ProfileConfigurations = [String: [KeyboardDeviceKey: DeviceConfiguration]]

    private let defaults: UserDefaults
    private let profileManager: ProfileManaging
    private let storageKey: String
    private let migrationVersionKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        profileManager: ProfileManaging? = nil,
        storageKey: String = "keyboardDeviceInputSourceMappings",
        migrationVersionKey: String = "keyboardDeviceInputSourceMappingsMigrationV2Completed"
    ) {
        self.defaults = defaults
        self.profileManager = profileManager ?? ProfileManager(defaults: defaults)
        self.storageKey = storageKey
        self.migrationVersionKey = migrationVersionKey

        migrateToV2IfNeeded()
    }

    func getMapping(for deviceKey: KeyboardDeviceKey) -> String? {
        loadConfigurations(for: activeProfileId)[deviceKey]?.mappingInputSourceId
    }

    func setMapping(deviceKey: KeyboardDeviceKey, inputSourceId: String) {
        var allConfigurations = loadAllConfigurations()
        var profileConfigurations = allConfigurations[activeProfileId] ?? [:]
        var configuration = profileConfigurations[deviceKey] ?? DeviceConfiguration()
        configuration.mappingInputSourceId = normalizedInputSourceId(inputSourceId)
        profileConfigurations[deviceKey] = configuration
        allConfigurations[activeProfileId] = profileConfigurations
        saveConfigurations(allConfigurations)
    }

    func getPerDeviceFallback(for deviceKey: KeyboardDeviceKey) -> String? {
        loadConfigurations(for: activeProfileId)[deviceKey]?.perDeviceFallbackInputSourceId
    }

    func setPerDeviceFallback(deviceKey: KeyboardDeviceKey, inputSourceId: String?) {
        var allConfigurations = loadAllConfigurations()
        var profileConfigurations = allConfigurations[activeProfileId] ?? [:]
        var configuration = profileConfigurations[deviceKey] ?? DeviceConfiguration()
        configuration.perDeviceFallbackInputSourceId = normalizedInputSourceId(inputSourceId)
        profileConfigurations[deviceKey] = configuration
        allConfigurations[activeProfileId] = profileConfigurations
        saveConfigurations(allConfigurations)
    }

    func removeMapping(deviceKey: KeyboardDeviceKey) {
        var allConfigurations = loadAllConfigurations()
        guard var profileConfigurations = allConfigurations[activeProfileId],
              var configuration = profileConfigurations[deviceKey] else {
            return
        }

        configuration.mappingInputSourceId = nil
        profileConfigurations[deviceKey] = configuration
        allConfigurations[activeProfileId] = profileConfigurations
        saveConfigurations(allConfigurations)
    }

    func removeProfileData(profileId: String) {
        let normalizedProfileId = normalizedProfileId(profileId)
        var allConfigurations = loadAllConfigurations()
        allConfigurations.removeValue(forKey: normalizedProfileId)
        saveConfigurations(allConfigurations)
    }

    func allMappings() -> [KeyboardDeviceKey: String] {
        loadConfigurations(for: activeProfileId).compactMapValues(\.mappingInputSourceId)
    }

    func allKnownDeviceKeys() -> [KeyboardDeviceKey] {
        Array(loadConfigurations(for: activeProfileId).keys)
    }

    func validateMappings(availableEnabledIds: Set<String>) -> [MappingConflict] {
        loadConfigurations(for: activeProfileId)
            .compactMap { deviceKey, configuration -> MappingConflict? in
                guard let sourceId = configuration.mappingInputSourceId else {
                    return nil
                }

                guard !availableEnabledIds.contains(sourceId) else {
                    return nil
                }

                return MappingConflict(
                    deviceKey: deviceKey,
                    mappedSourceId: sourceId,
                    reason: .missingOrDisabled
                )
            }
            .sorted { lhs, rhs in
                if lhs.deviceKey.id == rhs.deviceKey.id {
                    return lhs.mappedSourceId < rhs.mappedSourceId
                }

                return lhs.deviceKey.id < rhs.deviceKey.id
            }
    }

    private var activeProfileId: String {
        normalizedProfileId(profileManager.activeProfileId)
    }

    private func loadConfigurations(for profileId: String) -> [KeyboardDeviceKey: DeviceConfiguration] {
        let normalizedProfileId = normalizedProfileId(profileId)
        return loadAllConfigurations()[normalizedProfileId] ?? [:]
    }

    private func loadAllConfigurations() -> ProfileConfigurations {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }

        guard let entries = decodeStoredMappings(from: data) else {
            return [:]
        }

        var allConfigurations: ProfileConfigurations = [:]
        for entry in entries {
            let profileId = normalizedProfileId(entry.profileId)
            var profileConfigurations = allConfigurations[profileId] ?? [:]
            let configuration = DeviceConfiguration(
                mappingInputSourceId: normalizedInputSourceId(entry.inputSourceId),
                perDeviceFallbackInputSourceId: normalizedInputSourceId(entry.perDeviceFallbackInputSourceId)
            )

            if configuration.mappingInputSourceId != nil || configuration.perDeviceFallbackInputSourceId != nil {
                profileConfigurations[entry.deviceKey] = configuration
                allConfigurations[profileId] = profileConfigurations
            }
        }

        return allConfigurations
    }

    private func decodeStoredMappings(from data: Data) -> [StoredMapping]? {
        if let entries = try? decoder.decode([StoredMapping].self, from: data) {
            return entries
        }

        if let legacyEntries = try? decoder.decode([LegacyProfilelessStoredMapping].self, from: data) {
            return legacyEntries.map { entry in
                StoredMapping(
                    profileId: Profile.defaultProfileId,
                    deviceKey: entry.deviceKey,
                    inputSourceId: entry.inputSourceId,
                    perDeviceFallbackInputSourceId: entry.perDeviceFallbackInputSourceId
                )
            }
        }

        if let legacyEntries = try? decoder.decode([LegacyFlatStoredMapping].self, from: data) {
            return legacyEntries.map { legacyEntry in
                StoredMapping(
                    profileId: Profile.defaultProfileId,
                    deviceKey: KeyboardDeviceKey(
                        vendorId: legacyEntry.vendorId,
                        productId: legacyEntry.productId,
                        transport: legacyEntry.transport,
                        locationId: legacyEntry.locationId,
                        isBuiltIn: legacyEntry.isBuiltIn ?? inferBuiltIn(transport: legacyEntry.transport),
                        productName: legacyEntry.productName
                    ),
                    inputSourceId: legacyEntry.inputSourceId,
                    perDeviceFallbackInputSourceId: legacyEntry.perDeviceFallbackInputSourceId
                )
            }
        }

        return nil
    }

    private func saveConfigurations(_ allConfigurations: ProfileConfigurations) {
        let entries = allConfigurations
            .flatMap { profileId, profileConfigurations in
                profileConfigurations.compactMap { deviceKey, configuration -> StoredMapping? in
                    let mappingInputSourceId = normalizedInputSourceId(configuration.mappingInputSourceId)
                    let perDeviceFallbackInputSourceId = normalizedInputSourceId(configuration.perDeviceFallbackInputSourceId)

                    guard mappingInputSourceId != nil || perDeviceFallbackInputSourceId != nil else {
                        return nil
                    }

                    return StoredMapping(
                        profileId: normalizedProfileId(profileId),
                        deviceKey: deviceKey,
                        inputSourceId: mappingInputSourceId,
                        perDeviceFallbackInputSourceId: perDeviceFallbackInputSourceId
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.profileId == rhs.profileId {
                    return lhs.deviceKey.id < rhs.deviceKey.id
                }

                return lhs.profileId < rhs.profileId
            }

        guard let data = try? encoder.encode(entries) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    private func migrateToV2IfNeeded() {
        guard defaults.bool(forKey: migrationVersionKey) == false else {
            return
        }

        defer {
            defaults.set(true, forKey: migrationVersionKey)
        }

        guard let data = defaults.data(forKey: storageKey),
              let entries = decodeStoredMappings(from: data) else {
            return
        }

        var allConfigurations: ProfileConfigurations = [:]
        for entry in entries {
            let profileId = normalizedProfileId(entry.profileId)
            var profileConfigurations = allConfigurations[profileId] ?? [:]
            profileConfigurations[entry.deviceKey] = DeviceConfiguration(
                mappingInputSourceId: normalizedInputSourceId(entry.inputSourceId),
                perDeviceFallbackInputSourceId: normalizedInputSourceId(entry.perDeviceFallbackInputSourceId)
            )
            allConfigurations[profileId] = profileConfigurations
        }

        saveConfigurations(allConfigurations)
    }

    private func inferBuiltIn(transport: String?) -> Bool {
        guard let normalizedTransport = KeyboardFingerprint.normalizedTransport(transport) else {
            return false
        }

        return normalizedTransport.contains("internal")
            || normalizedTransport == "spi"
            || normalizedTransport == "i2c"
            || normalizedTransport == "ps2"
    }

    private func normalizedInputSourceId(_ inputSourceId: String?) -> String? {
        guard let inputSourceId, !inputSourceId.isEmpty else {
            return nil
        }

        return inputSourceId
    }

    private func normalizedProfileId(_ profileId: String?) -> String {
        guard let profileId, !profileId.isEmpty else {
            return Profile.defaultProfileId
        }

        return profileId
    }
}
