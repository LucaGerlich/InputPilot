import Foundation

struct Profile: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    let createdAt: Date

    static let defaultProfileId = "default"
    static let codingProfileId = "coding"

    static let defaultProfiles: [Profile] = [
        Profile(
            id: Profile.defaultProfileId,
            name: "Default",
            createdAt: Date(timeIntervalSince1970: 0)
        ),
        Profile(
            id: Profile.codingProfileId,
            name: "Coding",
            createdAt: Date(timeIntervalSince1970: 1)
        )
    ]
}
