import Foundation

final class MappingStore: MappingStoring {
    private struct StoredMapping: Codable {
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

    private let defaults: UserDefaults
    private let storageKey: String
    private let migrationVersionKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "keyboardDeviceInputSourceMappings",
        migrationVersionKey: String = "keyboardDeviceInputSourceMappingsMigrationV2Completed"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.migrationVersionKey = migrationVersionKey

        migrateToV2IfNeeded()
    }

    func getMapping(for deviceKey: KeyboardDeviceKey) -> String? {
        loadConfigurations()[deviceKey]?.mappingInputSourceId
    }

    func setMapping(deviceKey: KeyboardDeviceKey, inputSourceId: String) {
        var configurations = loadConfigurations()
        var configuration = configurations[deviceKey] ?? DeviceConfiguration()
        configuration.mappingInputSourceId = normalizedInputSourceId(inputSourceId)
        configurations[deviceKey] = configuration
        saveConfigurations(configurations)
    }

    func getPerDeviceFallback(for deviceKey: KeyboardDeviceKey) -> String? {
        loadConfigurations()[deviceKey]?.perDeviceFallbackInputSourceId
    }

    func setPerDeviceFallback(deviceKey: KeyboardDeviceKey, inputSourceId: String?) {
        var configurations = loadConfigurations()
        var configuration = configurations[deviceKey] ?? DeviceConfiguration()
        configuration.perDeviceFallbackInputSourceId = normalizedInputSourceId(inputSourceId)
        configurations[deviceKey] = configuration
        saveConfigurations(configurations)
    }

    func removeMapping(deviceKey: KeyboardDeviceKey) {
        var configurations = loadConfigurations()
        guard var configuration = configurations[deviceKey] else {
            return
        }

        configuration.mappingInputSourceId = nil
        configurations[deviceKey] = configuration
        saveConfigurations(configurations)
    }

    func allMappings() -> [KeyboardDeviceKey: String] {
        loadConfigurations().compactMapValues(\.mappingInputSourceId)
    }

    func allKnownDeviceKeys() -> [KeyboardDeviceKey] {
        Array(loadConfigurations().keys)
    }

    func validateMappings(availableEnabledIds: Set<String>) -> [MappingConflict] {
        loadConfigurations()
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

    private func loadConfigurations() -> [KeyboardDeviceKey: DeviceConfiguration] {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }

        guard let entries = decodeStoredMappings(from: data) else {
            return [:]
        }

        return configurations(from: entries)
    }

    private func configurations(from entries: [StoredMapping]) -> [KeyboardDeviceKey: DeviceConfiguration] {
        var configurations: [KeyboardDeviceKey: DeviceConfiguration] = [:]
        for entry in entries {
            let configuration = DeviceConfiguration(
                mappingInputSourceId: normalizedInputSourceId(entry.inputSourceId),
                perDeviceFallbackInputSourceId: normalizedInputSourceId(entry.perDeviceFallbackInputSourceId)
            )

            if configuration.mappingInputSourceId != nil || configuration.perDeviceFallbackInputSourceId != nil {
                configurations[entry.deviceKey] = configuration
            }
        }

        return configurations
    }

    private func decodeStoredMappings(from data: Data) -> [StoredMapping]? {
        if let entries = try? decoder.decode([StoredMapping].self, from: data) {
            return entries
        }

        if let legacyEntries = try? decoder.decode([LegacyFlatStoredMapping].self, from: data) {
            return legacyEntries.map { legacyEntry in
                StoredMapping(
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

    private func saveConfigurations(_ configurations: [KeyboardDeviceKey: DeviceConfiguration]) {
        let entries = configurations
            .compactMap { deviceKey, configuration -> StoredMapping? in
                let mappingInputSourceId = normalizedInputSourceId(configuration.mappingInputSourceId)
                let perDeviceFallbackInputSourceId = normalizedInputSourceId(configuration.perDeviceFallbackInputSourceId)

                guard mappingInputSourceId != nil || perDeviceFallbackInputSourceId != nil else {
                    return nil
                }

                return StoredMapping(
                    deviceKey: deviceKey,
                    inputSourceId: mappingInputSourceId,
                    perDeviceFallbackInputSourceId: perDeviceFallbackInputSourceId
                )
            }
            .sorted { $0.deviceKey.id < $1.deviceKey.id }

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

        let configurations = configurations(from: entries)
        saveConfigurations(configurations)
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
}
