import Foundation

enum PermissionStatus: String {
    case unknown
    case denied
    case granted

    var displayName: String {
        switch self {
        case .unknown:
            return "not granted yet"
        case .denied:
            return "denied"
        case .granted:
            return "granted"
        }
    }
}

struct InputStatusSnapshot {
    var permissionStatus: PermissionStatus
    var activeKeyboard: String
    var activeInputSource: String

    static let placeholder = InputStatusSnapshot(
        permissionStatus: .unknown,
        activeKeyboard: "none",
        activeInputSource: "none"
    )
}
