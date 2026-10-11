import Combine
import Foundation
import ServiceManagement

enum LoginItemStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
}

protocol LoginItemServicing: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

/// The app itself as a login item, through ServiceManagement (macOS 13+).
final class MainAppLoginItemService: LoginItemServicing {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// "Open at login" for the welcome window and Settings. Without it a menu bar
/// utility silently stops working after every restart.
@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status: LoginItemStatus
    @Published private(set) var lastError: String?
    private let service: LoginItemServicing

    /// Nil means the app itself; a default argument would be built outside
    /// the main actor.
    init(service: LoginItemServicing? = nil) {
        let service = service ?? MainAppLoginItemService()
        self.service = service
        self.status = service.status
    }

    var isEnabled: Bool {
        status != .disabled
    }

    func setEnabled(_ enabled: Bool) {
        // A new choice supersedes any earlier failure, even when it needs no
        // work - otherwise a stale error keeps blocking the welcome window.
        lastError = nil
        refresh()
        guard enabled != isEnabled else {
            return
        }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            lastError = enabled
                ? "Could not add InputPilot to your login items (\(error.localizedDescription)). You can add it in System Settings → General → Login Items."
                : "Could not remove InputPilot from your login items (\(error.localizedDescription))."
        }

        refresh()
    }

    func refresh() {
        let current = service.status
        if status != current {
            status = current
        }
    }

    func openSystemSettingsLoginItems() {
        service.openSystemSettingsLoginItems()
    }
}
