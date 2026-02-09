import Foundation

@MainActor
final class TemporaryOverrideStore: TemporaryOverrideStoring {
    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var overridesByFingerprintKey: [String: TemporaryOverride] = [:]
    private var persistedFingerprintKeys: Set<String> = []

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "temporaryKeyboardInputSourceOverrides"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        loadPersistedOverrides()
        clearExpired(now: Date())
    }

    func setOverride(
        deviceFingerprintKey: String,
        inputSourceId: String,
        expiresAt: Date?,
        persistAcrossLaunch: Bool
    ) {
        guard let normalizedDeviceFingerprintKey = normalizedFingerprintKey(deviceFingerprintKey),
              let normalizedInputSourceId = normalizedInputSourceId(inputSourceId) else {
            return
        }

        let newOverride = TemporaryOverride(
            deviceFingerprintKey: normalizedDeviceFingerprintKey,
            inputSourceId: normalizedInputSourceId,
            expiresAt: expiresAt
        )
        overridesByFingerprintKey[normalizedDeviceFingerprintKey] = newOverride

        if persistAcrossLaunch, expiresAt != nil {
            persistedFingerprintKeys.insert(normalizedDeviceFingerprintKey)
        } else {
            persistedFingerprintKeys.remove(normalizedDeviceFingerprintKey)
        }

        savePersistedOverrides()
    }

    func temporaryOverride(for deviceFingerprintKey: String, now: Date) -> TemporaryOverride? {
        clearExpired(now: now)
        guard let normalizedDeviceFingerprintKey = normalizedFingerprintKey(deviceFingerprintKey) else {
            return nil
        }

        return overridesByFingerprintKey[normalizedDeviceFingerprintKey]
    }

    func clearOverride(for deviceFingerprintKey: String) {
        guard let normalizedDeviceFingerprintKey = normalizedFingerprintKey(deviceFingerprintKey) else {
            return
        }

        overridesByFingerprintKey.removeValue(forKey: normalizedDeviceFingerprintKey)
        persistedFingerprintKeys.remove(normalizedDeviceFingerprintKey)
        savePersistedOverrides()
    }

    func clearExpired(now: Date) {
        let expiredKeys = overridesByFingerprintKey
            .filter { _, overrideValue in
                overrideValue.isExpired(at: now)
            }
            .map(\.key)

        guard !expiredKeys.isEmpty else {
            return
        }

        for key in expiredKeys {
            overridesByFingerprintKey.removeValue(forKey: key)
            persistedFingerprintKeys.remove(key)
        }

        savePersistedOverrides()
    }

    private func loadPersistedOverrides() {
        guard let data = defaults.data(forKey: storageKey),
              let persistedOverrides = try? decoder.decode([TemporaryOverride].self, from: data) else {
            return
        }

        for persistedOverride in persistedOverrides {
            guard persistedOverride.expiresAt != nil,
                  let normalizedDeviceFingerprintKey = normalizedFingerprintKey(persistedOverride.deviceFingerprintKey),
                  let normalizedInputSourceId = normalizedInputSourceId(persistedOverride.inputSourceId) else {
                continue
            }

            let normalizedOverride = TemporaryOverride(
                deviceFingerprintKey: normalizedDeviceFingerprintKey,
                inputSourceId: normalizedInputSourceId,
                expiresAt: persistedOverride.expiresAt
            )
            overridesByFingerprintKey[normalizedDeviceFingerprintKey] = normalizedOverride
            persistedFingerprintKeys.insert(normalizedDeviceFingerprintKey)
        }
    }

    private func savePersistedOverrides() {
        let persistedOverrides = persistedFingerprintKeys
            .compactMap { overridesByFingerprintKey[$0] }
            .filter { $0.expiresAt != nil }
            .sorted { lhs, rhs in
                lhs.deviceFingerprintKey < rhs.deviceFingerprintKey
            }

        guard !persistedOverrides.isEmpty else {
            defaults.removeObject(forKey: storageKey)
            return
        }

        guard let data = try? encoder.encode(persistedOverrides) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    private func normalizedFingerprintKey(_ deviceFingerprintKey: String) -> String? {
        let normalizedDeviceFingerprintKey = deviceFingerprintKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedDeviceFingerprintKey.isEmpty ? nil : normalizedDeviceFingerprintKey
    }

    private func normalizedInputSourceId(_ inputSourceId: String) -> String? {
        let normalizedInputSourceId = inputSourceId.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedInputSourceId.isEmpty ? nil : normalizedInputSourceId
    }
}
