import Foundation
import Testing
@testable import InputPilot

@MainActor
struct MappingStoreTests {
    @Test
    func codableRoundtripPersistsMappings() throws {
        let suiteName = "MappingStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageKey = "mappingStoreRoundtrip"
        let firstKey = KeyboardDeviceKey(vendorId: 1452, productId: 832, transport: "USB", locationId: 123)
        let secondKey = KeyboardDeviceKey(vendorId: 5426, productId: 12, transport: nil, locationId: nil)

        let writer = MappingStore(defaults: defaults, storageKey: storageKey)
        writer.setMapping(deviceKey: firstKey, inputSourceId: "com.apple.keylayout.US")
        writer.setMapping(deviceKey: secondKey, inputSourceId: "com.apple.keylayout.German")

        let reader = MappingStore(defaults: defaults, storageKey: storageKey)

        #expect(reader.getMapping(for: firstKey) == "com.apple.keylayout.US")
        #expect(reader.getMapping(for: secondKey) == "com.apple.keylayout.German")
        #expect(reader.allMappings().count == 2)
    }

    @Test
    func removeMappingDeletesEntry() throws {
        let suiteName = "MappingStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageKey = "mappingStoreRemove"
        let key = KeyboardDeviceKey(vendorId: 1452, productId: 832, transport: "USB", locationId: 123)

        let store = MappingStore(defaults: defaults, storageKey: storageKey)
        store.setMapping(deviceKey: key, inputSourceId: "com.apple.keylayout.US")
        #expect(store.getMapping(for: key) == "com.apple.keylayout.US")

        store.removeMapping(deviceKey: key)
        #expect(store.getMapping(for: key) == nil)
        #expect(store.allMappings().isEmpty)
    }

    @Test
    func validateMappingsReportsMissingOrDisabledSources() throws {
        let suiteName = "MappingStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageKey = "mappingStoreValidate"
        let validDevice = KeyboardDeviceKey(vendorId: 1452, productId: 832, transport: "USB", locationId: 123)
        let invalidDevice = KeyboardDeviceKey(vendorId: 9999, productId: 111, transport: "BT", locationId: nil)

        let store = MappingStore(defaults: defaults, storageKey: storageKey)
        store.setMapping(deviceKey: validDevice, inputSourceId: "com.apple.keylayout.US")
        store.setMapping(deviceKey: invalidDevice, inputSourceId: "com.apple.keylayout.Missing")

        let conflicts = store.validateMappings(availableEnabledIds: ["com.apple.keylayout.US"])

        #expect(conflicts.count == 1)
        #expect(conflicts.first?.deviceKey == invalidDevice)
        #expect(conflicts.first?.mappedSourceId == "com.apple.keylayout.Missing")
        #expect(conflicts.first?.reason == .missingOrDisabled)
    }

    @Test
    func perDeviceFallbackRoundtripPersistsWithoutMapping() throws {
        let suiteName = "MappingStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageKey = "mappingStoreFallbackRoundtrip"
        let deviceKey = KeyboardDeviceKey(vendorId: 1452, productId: 832, transport: "USB", locationId: 123)

        let writer = MappingStore(defaults: defaults, storageKey: storageKey)
        writer.setPerDeviceFallback(deviceKey: deviceKey, inputSourceId: "com.apple.keylayout.US")

        let reader = MappingStore(defaults: defaults, storageKey: storageKey)

        #expect(reader.getMapping(for: deviceKey) == nil)
        #expect(reader.getPerDeviceFallback(for: deviceKey) == "com.apple.keylayout.US")
        #expect(reader.allKnownDeviceKeys().contains(deviceKey))
    }

    @Test
    func migrationRewritesLegacyPayloadToV2AndSetsFlag() throws {
        let suiteName = "MappingStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageKey = "mappingStoreLegacyMigration"
        let migrationKey = "mappingStoreLegacyMigrationFlag"
        let legacyEntries = [
            LegacyFlatStoredMapping(
                vendorId: 1452,
                productId: 832,
                transport: "USB",
                locationId: 321,
                inputSourceId: "com.apple.keylayout.US",
                perDeviceFallbackInputSourceId: nil
            )
        ]
        let legacyData = try JSONEncoder().encode(legacyEntries)
        defaults.set(legacyData, forKey: storageKey)

        let store = MappingStore(
            defaults: defaults,
            storageKey: storageKey,
            migrationVersionKey: migrationKey
        )
        let key = KeyboardDeviceKey(vendorId: 1452, productId: 832, transport: "USB", locationId: 321)

        #expect(store.getMapping(for: key) == "com.apple.keylayout.US")
        #expect(defaults.bool(forKey: migrationKey))

        let migratedData = try #require(defaults.data(forKey: storageKey))
        let migratedPayload = try #require(String(data: migratedData, encoding: .utf8))
        #expect(migratedPayload.contains("\"fingerprint\""))
    }

    @Test
    func migrationSkipsWhenFlagAlreadySet() throws {
        let suiteName = "MappingStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.failedToCreateUserDefaultsSuite
        }

        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let storageKey = "mappingStoreLegacyMigrationSkip"
        let migrationKey = "mappingStoreLegacyMigrationSkipFlag"
        let legacyEntries = [
            LegacyFlatStoredMapping(
                vendorId: 1452,
                productId: 832,
                transport: "USB",
                locationId: 444,
                inputSourceId: "com.apple.keylayout.US",
                perDeviceFallbackInputSourceId: nil
            )
        ]
        let legacyData = try JSONEncoder().encode(legacyEntries)
        defaults.set(true, forKey: migrationKey)
        defaults.set(legacyData, forKey: storageKey)

        _ = MappingStore(
            defaults: defaults,
            storageKey: storageKey,
            migrationVersionKey: migrationKey
        )

        let storedData = try #require(defaults.data(forKey: storageKey))
        let storedPayload = try #require(String(data: storedData, encoding: .utf8))
        #expect(storedPayload.contains("\"vendorId\""))
        #expect(storedPayload.contains("\"locationId\""))
        #expect(storedPayload.contains("\"inputSourceId\""))
        #expect(!storedPayload.contains("\"fingerprint\""))
    }
}

private struct LegacyFlatStoredMapping: Codable {
    let vendorId: Int
    let productId: Int
    let transport: String?
    let locationId: Int?
    let inputSourceId: String?
    let perDeviceFallbackInputSourceId: String?
}

private enum TestError: Error {
    case failedToCreateUserDefaultsSuite
}
