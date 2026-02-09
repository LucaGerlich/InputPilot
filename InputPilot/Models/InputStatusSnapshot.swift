import Foundation

enum PermissionStatus: String {
    case unknown
    case denied
    case granted
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
