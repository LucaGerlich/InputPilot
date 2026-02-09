import Foundation

@MainActor
final class AppSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func bool(forKey key: String, default defaultValue: Bool = false) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
