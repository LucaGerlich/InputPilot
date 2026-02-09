import Foundation

final class MappingStore {
    private struct StoredMapping: Codable {
        let deviceKey: KeyboardDeviceKey
        let inputSourceId: String
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "keyboardDeviceInputSourceMappings"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func getMapping(for deviceKey: KeyboardDeviceKey) -> String? {
        loadMappings()[deviceKey]
    }

    func setMapping(deviceKey: KeyboardDeviceKey, inputSourceId: String) {
        var mappings = loadMappings()
        mappings[deviceKey] = inputSourceId
        saveMappings(mappings)
    }

    func removeMapping(deviceKey: KeyboardDeviceKey) {
        var mappings = loadMappings()
        mappings.removeValue(forKey: deviceKey)
        saveMappings(mappings)
    }

    func allMappings() -> [KeyboardDeviceKey: String] {
        loadMappings()
    }

    private func loadMappings() -> [KeyboardDeviceKey: String] {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }

        guard let entries = try? decoder.decode([StoredMapping].self, from: data) else {
            return [:]
        }

        var mappings: [KeyboardDeviceKey: String] = [:]
        for entry in entries {
            mappings[entry.deviceKey] = entry.inputSourceId
        }

        return mappings
    }

    private func saveMappings(_ mappings: [KeyboardDeviceKey: String]) {
        let entries = mappings
            .map { StoredMapping(deviceKey: $0.key, inputSourceId: $0.value) }
            .sorted { $0.deviceKey.id < $1.deviceKey.id }

        guard let data = try? encoder.encode(entries) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}
