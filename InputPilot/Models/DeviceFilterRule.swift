import Foundation

struct DeviceFilterRule: Codable, Equatable {
    enum Mode: String, Codable, CaseIterable, Identifiable {
        case allowList
        case denyList

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .allowList:
                return "Allow only selected"
            case .denyList:
                return "Block selected"
            }
        }
    }

    var mode: Mode
    var fingerprints: Set<KeyboardFingerprint>

    init() {
        self.mode = .denyList
        self.fingerprints = Set<KeyboardFingerprint>()
    }

    init(
        mode: Mode,
        fingerprints: Set<KeyboardFingerprint>
    ) {
        self.mode = mode
        self.fingerprints = fingerprints
    }

    func isDeviceEnabled(_ fingerprint: KeyboardFingerprint) -> Bool {
        switch mode {
        case .denyList:
            return !contains(fingerprint)
        case .allowList:
            return contains(fingerprint)
        }
    }

    func contains(_ fingerprint: KeyboardFingerprint) -> Bool {
        fingerprints.contains(where: { $0.matchesPrimary(of: fingerprint) })
    }

    mutating func setDeviceEnabled(_ enabled: Bool, for fingerprint: KeyboardFingerprint) {
        removeAllMatchingPrimaryFingerprint(fingerprint)

        switch mode {
        case .denyList:
            if !enabled {
                fingerprints.insert(canonicalFilterFingerprint(fingerprint))
            }
        case .allowList:
            if enabled {
                fingerprints.insert(canonicalFilterFingerprint(fingerprint))
            }
        }
    }

    private mutating func removeAllMatchingPrimaryFingerprint(_ fingerprint: KeyboardFingerprint) {
        fingerprints = Set(
            fingerprints.filter { candidate in
                !candidate.matchesPrimary(of: fingerprint)
            }
        )
    }

    private func canonicalFilterFingerprint(_ fingerprint: KeyboardFingerprint) -> KeyboardFingerprint {
        KeyboardFingerprint(
            vendorId: fingerprint.vendorId,
            productId: fingerprint.productId,
            transport: fingerprint.normalizedTransport ?? fingerprint.transport,
            isBuiltIn: fingerprint.isBuiltIn,
            productName: fingerprint.normalizedProductName ?? fingerprint.productName,
            locationId: nil
        )
    }
}
