import Foundation

/// Rules for matching an observed keyboard against the keys InputPilot already
/// knows. Every input arrives as a parameter, so the rules carry no state.
enum DeviceKeyResolver {
    /// The input source configured for a device, through `sourceFor` (a
    /// mapping or a fallback). Falls back to another known key with the same
    /// primary fingerprint, so a re-plugged keyboard keeps its configuration.
    static func configuredInputSourceId(
        for observedDeviceKey: KeyboardDeviceKey,
        knownKeys: [KeyboardDeviceKey],
        sourceFor: (KeyboardDeviceKey) -> String?,
        isEnabled: (String) -> Bool
    ) -> String? {
        if let exactSourceId = sourceFor(observedDeviceKey), isEnabled(exactSourceId) {
            return exactSourceId
        }

        let primaryCandidates = knownKeys
            .filter { $0.matchesPrimary(of: observedDeviceKey.fingerprint) }
            .filter { $0 != observedDeviceKey }

        guard !primaryCandidates.isEmpty else {
            return nil
        }

        let resolvedCandidates: [(key: KeyboardDeviceKey, sourceId: String)] = primaryCandidates.compactMap { candidateKey in
            guard let sourceId = sourceFor(candidateKey), isEnabled(sourceId) else {
                return nil
            }

            return (key: candidateKey, sourceId: sourceId)
        }

        guard !resolvedCandidates.isEmpty else {
            return nil
        }

        if resolvedCandidates.count == 1 {
            return resolvedCandidates[0].sourceId
        }

        if let observedLocationId = observedDeviceKey.locationId,
           let locationMatchedCandidate = resolvedCandidates.first(where: { $0.key.locationId == observedLocationId }) {
            return locationMatchedCandidate.sourceId
        }

        if let locationAgnosticCandidate = resolvedCandidates.first(where: { $0.key.locationId == nil }) {
            return locationAgnosticCandidate.sourceId
        }

        return resolvedCandidates
            .sorted(by: { lhs, rhs in
                lhs.key.id.localizedCaseInsensitiveCompare(rhs.key.id) == .orderedAscending
            })
            .first?
            .sourceId
    }

    /// The known key an observed device should be filed under, or the observed
    /// key itself when it is a keyboard InputPilot has not seen before.
    static func canonicalKey(
        for observedDeviceKey: KeyboardDeviceKey,
        among existingKeys: [KeyboardDeviceKey]
    ) -> KeyboardDeviceKey {
        let primaryMatches = existingKeys.filter { $0.matchesPrimary(of: observedDeviceKey.fingerprint) }

        if let exactMatch = primaryMatches.first(where: { $0 == observedDeviceKey }) {
            return exactMatch
        }

        if primaryMatches.count == 1, let existingPrimaryMatch = primaryMatches.first {
            return existingPrimaryMatch
        }

        if let observedLocationId = observedDeviceKey.locationId,
           let locationMatchedKey = primaryMatches.first(where: { $0.locationId == observedLocationId }) {
            return locationMatchedKey
        }

        if let locationAgnosticKey = primaryMatches.first(where: { $0.locationId == nil }) {
            return locationAgnosticKey
        }

        return observedDeviceKey
    }

    /// Whether `deviceKey` stands for the keyboard currently being typed on.
    static func isActiveDevice(
        _ activeDeviceKey: KeyboardDeviceKey,
        representedBy deviceKey: KeyboardDeviceKey,
        knownKeys: [KeyboardDeviceKey]
    ) -> Bool {
        if activeDeviceKey == deviceKey {
            return true
        }

        guard activeDeviceKey.matchesPrimary(of: deviceKey.fingerprint) else {
            return false
        }

        let primaryMatches = knownKeys.filter { $0.matchesPrimary(of: activeDeviceKey.fingerprint) }
        if primaryMatches.count <= 1 {
            return true
        }

        return activeDeviceKey.locationId == deviceKey.locationId
    }
}
