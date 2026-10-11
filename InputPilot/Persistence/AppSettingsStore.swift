import Foundation

@MainActor
final class AppSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func bool(forKey key: String, default defaultValue: Bool = false) -> Bool {
        // bool(forKey:) also reads "YES"/"NO" strings, as launch arguments
        // such as `-onboardingCompleted NO` arrive.
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func date(forKey key: String) -> Date? {
        defaults.object(forKey: key) as? Date
    }

    func set(_ value: Date?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func string(forKey key: String) -> String? {
        defaults.object(forKey: key) as? String
    }

    func set(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
