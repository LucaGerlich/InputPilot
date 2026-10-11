import Foundation
import Testing
@testable import InputPilot

@MainActor
struct LoginItemControllerTests {
    @Test
    func enablingRegistersAndReportsEnabled() {
        let service = MockLoginItemService()
        let controller = LoginItemController(service: service)
        #expect(controller.status == .disabled)

        controller.setEnabled(true)

        #expect(service.registerCount == 1)
        #expect(controller.status == .enabled)
        #expect(controller.lastError == nil)
    }

    @Test
    func aFailedRegistrationIsReportedNotSwallowed() {
        let service = MockLoginItemService()
        service.registerError = LoginItemTestError.denied
        let controller = LoginItemController(service: service)

        controller.setEnabled(true)

        #expect(controller.status == .disabled)
        #expect(controller.lastError != nil)
    }

    @Test
    func uncheckingAfterAFailedRegistrationClearsTheError() {
        let service = MockLoginItemService()
        service.registerError = LoginItemTestError.denied
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        #expect(controller.lastError != nil)

        // Otherwise the welcome window's Done stays blocked by a stale error.
        controller.setEnabled(false)

        #expect(controller.lastError == nil)
    }

    @Test
    func pendingApprovalIsSurfaced() {
        let service = MockLoginItemService()
        service.statusAfterRegister = .requiresApproval
        let controller = LoginItemController(service: service)

        controller.setEnabled(true)

        #expect(controller.status == .requiresApproval)
    }

    @Test
    func enablingWhenAlreadyEnabledDoesNotRegisterAgain() {
        let service = MockLoginItemService()
        service.status = .enabled
        let controller = LoginItemController(service: service)

        controller.setEnabled(true)
        controller.setEnabled(false)

        #expect(service.registerCount == 0)
        #expect(service.unregisterCount == 1)
        #expect(controller.status == .disabled)
    }
}

private final class MockLoginItemService: LoginItemServicing {
    var status: LoginItemStatus = .disabled
    var statusAfterRegister: LoginItemStatus = .enabled
    var registerError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    func register() throws {
        if let registerError {
            throw registerError
        }
        registerCount += 1
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCount += 1
        status = .disabled
    }

    func openSystemSettingsLoginItems() {}
}

private enum LoginItemTestError: Error {
    case denied
}
