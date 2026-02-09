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
}

private enum TestError: Error {
    case failedToCreateUserDefaultsSuite
}
