import Foundation

struct MappingConflict: Identifiable, Equatable {
    enum Reason: String, Equatable {
        case missingOrDisabled = "missing/disabled"
    }

    let deviceKey: KeyboardDeviceKey
    let mappedSourceId: String
    let reason: Reason

    var id: String {
        "\(deviceKey.id)|\(mappedSourceId)|\(reason.rawValue)"
    }
}
