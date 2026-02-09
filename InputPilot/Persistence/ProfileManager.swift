import Foundation

@MainActor
final class ProfileManager: ProfileManaging {
    private let defaults: UserDefaults
    private let profilesStorageKey: String
    private let activeProfileStorageKey: String

    private var storedProfiles: [Profile]
    private var storedActiveProfileId: String

    init(
        defaults: UserDefaults = .standard,
        profilesStorageKey: String = "profiles.v1",
        activeProfileStorageKey: String = "activeProfileId.v1"
    ) {
        self.defaults = defaults
        self.profilesStorageKey = profilesStorageKey
        self.activeProfileStorageKey = activeProfileStorageKey

        let loadedProfiles = Self.loadProfiles(from: defaults, key: profilesStorageKey)
        self.storedProfiles = Self.ensureDefaultProfiles(in: loadedProfiles)

        let preferredActiveId = defaults.string(forKey: activeProfileStorageKey)
        self.storedActiveProfileId = Self.resolveActiveProfileId(
            preferredActiveId: preferredActiveId,
            profiles: storedProfiles
        )

        persistProfiles()
        persistActiveProfileId()
    }

    var profiles: [Profile] {
        storedProfiles
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

                return lhs.createdAt < rhs.createdAt
            }
    }

    var activeProfileId: String {
        storedActiveProfileId
    }

    @discardableResult
    func createProfile(name: String) -> Profile {
        let baseName = Self.normalizedProfileName(name) ?? "Profile"
        let uniqueName = Self.makeUniqueName(baseName, existingNames: storedProfiles.map(\.name))
        let profile = Profile(
            id: UUID().uuidString.lowercased(),
            name: uniqueName,
            createdAt: Date()
        )
        storedProfiles.append(profile)
        persistProfiles()
        return profile
    }

    func renameProfile(id: String, name: String) {
        guard let index = storedProfiles.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard let normalizedName = Self.normalizedProfileName(name) else {
            return
        }

        let otherNames = storedProfiles
            .enumerated()
            .filter { $0.offset != index }
            .map { $0.element.name }
        let uniqueName = Self.makeUniqueName(normalizedName, existingNames: otherNames)

        storedProfiles[index].name = uniqueName
        persistProfiles()
    }

    @discardableResult
    func deleteProfile(id: String) -> Bool {
        guard storedProfiles.count > 1 else {
            return false
        }

        guard let index = storedProfiles.firstIndex(where: { $0.id == id }) else {
            return false
        }

        storedProfiles.remove(at: index)

        if storedActiveProfileId == id {
            storedActiveProfileId = Self.resolveActiveProfileId(
                preferredActiveId: Profile.defaultProfileId,
                profiles: storedProfiles
            )
            persistActiveProfileId()
        }

        persistProfiles()
        return true
    }

    func setActiveProfile(id: String) {
        guard storedProfiles.contains(where: { $0.id == id }) else {
            return
        }

        guard storedActiveProfileId != id else {
            return
        }

        storedActiveProfileId = id
        persistActiveProfileId()
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(storedProfiles) else {
            return
        }

        defaults.set(data, forKey: profilesStorageKey)
    }

    private func persistActiveProfileId() {
        defaults.set(storedActiveProfileId, forKey: activeProfileStorageKey)
    }

    private static func loadProfiles(from defaults: UserDefaults, key: String) -> [Profile] {
        guard let data = defaults.data(forKey: key),
              let profiles = try? JSONDecoder().decode([Profile].self, from: data) else {
            return []
        }

        return profiles
    }

    private static func ensureDefaultProfiles(in profiles: [Profile]) -> [Profile] {
        var mergedProfiles = profiles
        for defaultProfile in Profile.defaultProfiles {
            if !mergedProfiles.contains(where: { $0.id == defaultProfile.id }) {
                mergedProfiles.append(defaultProfile)
            }
        }

        if mergedProfiles.isEmpty {
            mergedProfiles = Profile.defaultProfiles
        }

        return mergedProfiles
    }

    private static func resolveActiveProfileId(
        preferredActiveId: String?,
        profiles: [Profile]
    ) -> String {
        if let preferredActiveId,
           profiles.contains(where: { $0.id == preferredActiveId }) {
            return preferredActiveId
        }

        if profiles.contains(where: { $0.id == Profile.defaultProfileId }) {
            return Profile.defaultProfileId
        }

        return profiles.first?.id ?? Profile.defaultProfileId
    }

    private static func normalizedProfileName(_ name: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? nil : trimmedName
    }

    private static func makeUniqueName(_ baseName: String, existingNames: [String]) -> String {
        let normalizedExistingNames = Set(existingNames.map { $0.lowercased() })
        if !normalizedExistingNames.contains(baseName.lowercased()) {
            return baseName
        }

        var suffix = 2
        while true {
            let candidate = "\(baseName) \(suffix)"
            if !normalizedExistingNames.contains(candidate.lowercased()) {
                return candidate
            }
            suffix += 1
        }
    }
}
