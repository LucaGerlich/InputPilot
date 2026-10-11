import Foundation

struct MappingConflict: Identifiable, Equatable {
    enum Reason: String, Equatable {
        case missingOrDisabled = "missing/disabled"

        var explanation: String {
            switch self {
            case .missingOrDisabled:
                return "The input source was removed or disabled."
            }
        }
    }

    let deviceKey: KeyboardDeviceKey
    let mappedSourceId: String
    let reason: Reason

    var id: String {
        "\(deviceKey.id)|\(mappedSourceId)|\(reason.rawValue)"
    }
}
