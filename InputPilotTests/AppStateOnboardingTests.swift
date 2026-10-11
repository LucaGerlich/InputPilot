import Foundation
import IOKit.hid
import Testing
@testable import InputPilot

/// The first run: asking for Input Monitoring, finishing onboarding, and the
/// states in between that once left new users with an inert app.
@MainActor
struct AppStateOnboardingTests {
    private let exclusiveAccess = "Another app has exclusive access to a keyboard."

    @Test
    func firstRunRequestsPermissionAndOnboardingLastsUntilCompleted() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let permission = MockPermissionService(accessType: kIOHIDAccessTypeUnknown)
        let monitor = MockHIDKeyboardMonitor()
        let appState = makeAppState(defaults: defaults, permission: permission, monitor: monitor)

        #expect(appState.needsOnboarding)
        #expect(!monitor.isRunning)

        // 1.0.0 only ever checked the permission and never asked for it.
        appState.requestInputMonitoringPermission()

        #expect(permission.requestCount == 1)
        #expect(appState.status.permissionStatus == .granted)
        #expect(monitor.isRunning)
        #expect(appState.needsOnboarding)

        appState.completeOnboarding()
        #expect(!appState.needsOnboarding)

        let relaunched = makeAppState(defaults: defaults, permission: permission, monitor: MockHIDKeyboardMonitor())
        #expect(!relaunched.needsOnboarding)
    }

    @Test
    func onboardingReturnsWhilePermissionIsMissingEvenAfterCompletion() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "onboardingCompleted")

        let appState = makeAppState(
            defaults: defaults,
            permission: MockPermissionService(accessType: kIOHIDAccessTypeDenied),
            monitor: MockHIDKeyboardMonitor()
        )

        #expect(appState.needsOnboarding)
    }

    @Test
    func stringBooleansFromLaunchArgumentsAreRead() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(defaults: defaults)

        // `-onboardingCompleted NO` arrives as the string "NO".
        defaults.set("NO", forKey: "flag")
        #expect(store.bool(forKey: "flag", default: true) == false)
        defaults.set("YES", forKey: "flag")
        #expect(store.bool(forKey: "flag", default: false) == true)
        #expect(store.bool(forKey: "missing", default: true) == true)
    }

    @Test
    func keyboardHeldByAnotherAppIsAPartialStartWhenPermissionWasAlreadyGranted() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let monitor = MockHIDKeyboardMonitor()
        monitor.exclusiveAccessMessage = exclusiveAccess

        let appState = makeAppState(
            defaults: defaults,
            permission: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            monitor: monitor
        )

        #expect(monitor.allowsPartialOpen)
        #expect(monitor.isRunning)
        #expect(!appState.needsRelaunchAfterGrant)
        #expect(appState.keyboardMonitorHint == exclusiveAccess)
        #expect(appState.monitorHasPartialAccess)
    }

    @Test
    func keyboardHeldByAnotherAppRightAfterAFreshGrantStillAsksForARelaunch() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let monitor = MockHIDKeyboardMonitor()
        monitor.exclusiveAccessMessage = exclusiveAccess

        // A fresh grant may not apply to this process yet, and the open error
        // comes from an unordered set of devices - it could hide that.
        let appState = makeAppState(
            defaults: defaults,
            permission: MockPermissionService(accessType: kIOHIDAccessTypeUnknown),
            monitor: monitor
        )
        appState.requestInputMonitoringPermission()

        #expect(!monitor.allowsPartialOpen)
        #expect(!monitor.isRunning)
        #expect(appState.needsRelaunchAfterGrant)
    }

    // MARK: - Helpers

    private func makeAppState(
        defaults: UserDefaults,
        permission: MockPermissionService,
        monitor: MockHIDKeyboardMonitor
    ) -> AppState {
        AppState(
            permissionService: permission,
            hidKeyboardMonitor: monitor,
            inputSourceService: MockInputSourceService(),
            mappingStore: MockMappingStore(),
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: ImmediateClock()
        )
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AppStateOnboardingTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw OnboardingTestError.failedToCreateUserDefaultsSuite
        }

        return (defaults, suiteName)
    }
}

private enum OnboardingTestError: Error {
    case failedToCreateUserDefaultsSuite
}
