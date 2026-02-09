import Foundation

struct MappingBackupEntry: Codable, Equatable, Hashable {
    let profileId: String
    let deviceKey: KeyboardDeviceKey
    let inputSourceId: String?
    let perDeviceFallbackInputSourceId: String?
}
