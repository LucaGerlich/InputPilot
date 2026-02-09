import Foundation

struct TemporaryOverride: Codable, Hashable, Identifiable {
    let deviceFingerprintKey: String
    let inputSourceId: String
    let expiresAt: Date?

    var id: String {
        deviceFingerprintKey
    }

    func isExpired(at referenceDate: Date) -> Bool {
        guard let expiresAt else {
            return false
        }

        return expiresAt <= referenceDate
    }
}
