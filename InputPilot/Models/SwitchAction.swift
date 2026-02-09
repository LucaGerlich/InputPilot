import Foundation

struct SwitchAction: Equatable {
    let timestamp: Date
    let fromInputSourceId: String?
    let toInputSourceId: String
    let deviceFingerprint: String
    let deviceDisplayName: String
}
