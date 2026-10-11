import Foundation
import IOKit.hid
import Testing
@testable import InputPilot

/// What happens when the input source changes outside InputPilot - ⌃Space,
/// the menu bar, Undo, an input method switching modes.
@MainActor
struct AppStateManualChangeTests {
    private let us = "com.apple.keylayout.US"
    private let german = "com.apple.keylayout.German"
    private let french = "com.apple.keylayout.French"

    private let macBook = ActiveKeyboardDevice(
        vendorId: 1452,
        productId: 832,
        productName: "Apple Keyboard",
        transport: "USB",
        locationId: 100
    )
    private let keychron = ActiveKeyboardDevice(
        vendorId: 13364,
        productId: 630,
        productName: "Keychron K2",
        transport: "Bluetooth",
        locationId: 200
    )

    @Test
    func defaultPolicyKeepsAManualChangeUntilTheKeyboardChanges() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = ImmediateClock()
        let harness = makeHarness(defaults: defaults, clock: clock)
        #expect(harness.appState.manualChangePolicy == .keepUntilKeyboardChange)

        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls == [us] }

        // The user picks French on the same keyboard, e.g. with ⌃Space.
        clock.advance(by: .seconds(2))
        harness.sources.currentInputSourceIdValue = french
        harness.monitor.emit(macBook)
        await waitFor { harness.appState.manualHoldDescription != nil }
        #expect(harness.sources.selectCalls == [us])

        // Typing on the other keyboard ends the hold, and so does coming back.
        harness.monitor.emit(keychron)
        await waitFor { harness.sources.selectCalls.count == 2 }
        clock.advance(by: .seconds(2))
        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls.count == 3 }

        #expect(harness.sources.selectCalls == [us, german, us])
        #expect(harness.appState.manualHoldDescription == nil)
    }

    @Test
    func keepUntilSwitchBackHoldsAcrossKeyboardsUntilTheMappedSourceReturns() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = ImmediateClock()
        let harness = makeHarness(defaults: defaults, clock: clock, policy: .keepUntilSwitchBack)

        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls == [us] }

        clock.advance(by: .seconds(2))
        harness.sources.currentInputSourceIdValue = french
        harness.monitor.emit(macBook)
        await waitFor { harness.appState.manualHoldDescription != nil }

        // Another keyboard does not end this hold.
        harness.monitor.emit(keychron)
        await waitFor { harness.appState.activeKeyboardDevice == keychron }
        await settle()
        #expect(harness.sources.selectCalls == [us])

        // Switching to that keyboard's own layout by hand re-arms switching.
        harness.sources.currentInputSourceIdValue = german
        harness.monitor.emit(keychron)
        await settle()
        #expect(harness.appState.manualHoldDescription == nil)

        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls.count == 2 }
        #expect(harness.sources.selectCalls == [us, us])
    }

    @Test
    func revertPolicySwitchesBackOnTheNextKeyPress() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = ImmediateClock()
        let harness = makeHarness(defaults: defaults, clock: clock, policy: .revertOnNextKeyPress)

        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls == [us] }

        clock.advance(by: .seconds(2))
        harness.sources.currentInputSourceIdValue = french
        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls.count == 2 }

        #expect(harness.sources.selectCalls == [us, us])
        #expect(harness.appState.manualHoldDescription == nil)
    }

    @Test
    func turnOffPolicyDisablesAutoSwitchAndSaysWhy() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = ImmediateClock()
        let harness = makeHarness(defaults: defaults, clock: clock, policy: .turnOffAutoSwitch)

        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls == [us] }

        clock.advance(by: .seconds(2))
        harness.sources.currentInputSourceIdValue = french
        harness.monitor.emit(macBook)
        await waitFor { !harness.appState.autoSwitchEnabled }

        #expect(harness.sources.selectCalls == [us])
        #expect(harness.appState.autoSwitchOffReason != nil)

        harness.appState.setAutoSwitchEnabled(true)
        #expect(harness.appState.autoSwitchOffReason == nil)
    }

    @Test
    func undoSticksUnderTheDefaultPolicy() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = ImmediateClock()
        let harness = makeHarness(defaults: defaults, clock: clock)

        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls == [us] }

        harness.appState.undoLastSwitch()
        #expect(harness.sources.selectCalls == [us, german])

        clock.advance(by: .seconds(2))
        harness.monitor.emit(macBook)
        await waitFor { harness.appState.manualHoldDescription != nil }
        #expect(harness.sources.selectCalls == [us, german])
    }

    @Test
    func changingAMappingEndsTheHoldAndAppliesAtOnce() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = ImmediateClock()
        let harness = makeHarness(defaults: defaults, clock: clock)

        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls == [us] }

        clock.advance(by: .seconds(2))
        harness.sources.currentInputSourceIdValue = french
        harness.monitor.emit(macBook)
        await waitFor { harness.appState.manualHoldDescription != nil }

        harness.appState.setMapping(for: KeyboardDeviceKey(device: macBook), inputSourceId: us)
        await waitFor { harness.sources.selectCalls.count == 2 }

        #expect(harness.sources.selectCalls == [us, us])
        #expect(harness.appState.manualHoldDescription == nil)
    }

    @Test
    func policyPersistsAcrossLaunches() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        makeHarness(defaults: defaults, clock: ImmediateClock())
            .appState.setManualChangePolicy(.revertOnNextKeyPress)
        let relaunched = makeHarness(defaults: defaults, clock: ImmediateClock())

        #expect(relaunched.appState.manualChangePolicy == .revertOnNextKeyPress)
    }

    @Test
    func manualChangeInsideTheDebounceWindowAfterSwitchingKeyboardsIsKept() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = GatedClock()
        let harness = makeHarness(defaults: defaults, clock: clock)
        harness.sources.currentInputSourceIdValue = us

        harness.monitor.emit(keychron)
        await waitFor { clock.hasSleepers }
        clock.releaseSleepers()
        await waitFor { harness.sources.selectCalls == [german] }

        // Move to the MacBook; its switch to U.S. is now waiting out the debounce...
        clock.advance(by: 2)
        harness.monitor.emit(macBook)
        await waitFor { clock.hasSleepers }

        // ...and the user presses ⌃Space for French before it fires.
        harness.sources.currentInputSourceIdValue = french
        clock.releaseSleepers()
        await waitFor { harness.appState.manualHoldDescription != nil }

        #expect(harness.sources.selectCalls == [german])
    }

    @Test
    func aSwitchThatDoesNotTakeIsRetriedRatherThanTreatedAsManual() async throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let clock = ImmediateClock()
        let harness = makeHarness(defaults: defaults, clock: clock)
        harness.sources.selectTakesEffect = false

        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls == [us] }

        clock.advance(by: .seconds(2))
        harness.monitor.emit(macBook)
        await waitFor { harness.sources.selectCalls.count == 2 }

        #expect(harness.sources.selectCalls == [us, us])
        #expect(harness.appState.manualHoldDescription == nil)
    }

    // MARK: - Helpers

    private struct Harness {
        let appState: AppState
        let monitor: MockHIDKeyboardMonitor
        let sources: MockInputSourceService
    }

    private func makeHarness(
        defaults: UserDefaults,
        clock: ClockProviding,
        policy: ManualChangePolicy? = nil
    ) -> Harness {
        let monitor = MockHIDKeyboardMonitor()
        let sources = MockInputSourceService()
        sources.enabledSources = [
            InputSourceInfo(id: us, name: "U.S.", isSelectable: true),
            InputSourceInfo(id: german, name: "German", isSelectable: true),
            InputSourceInfo(id: french, name: "French", isSelectable: true)
        ]
        sources.currentInputSourceIdValue = german

        let mappingStore = MockMappingStore()
        mappingStore.setMapping(deviceKey: KeyboardDeviceKey(device: macBook), inputSourceId: us)
        mappingStore.setMapping(deviceKey: KeyboardDeviceKey(device: keychron), inputSourceId: german)

        let appState = AppState(
            permissionService: MockPermissionService(accessType: kIOHIDAccessTypeGranted),
            hidKeyboardMonitor: monitor,
            inputSourceService: sources,
            mappingStore: mappingStore,
            appSettingsStore: AppSettingsStore(defaults: defaults),
            clock: clock
        )
        if let policy {
            appState.setManualChangePolicy(policy)
        }

        return Harness(appState: appState, monitor: monitor, sources: sources)
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AppStateManualChangeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw ManualChangeTestError.failedToCreateUserDefaultsSuite
        }

        return (defaults, suiteName)
    }

    private func waitFor(
        maxAttempts: Int = 300,
        condition: @escaping () -> Bool
    ) async {
        for _ in 0..<maxAttempts {
            if condition() {
                return
            }

            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    /// For "nothing happens" checks: with an immediate clock the debounce has
    /// long fired after 100 ms, so anything that would switch has switched.
    private func settle() async {
        await waitFor(maxAttempts: 20) { false }
    }
}

private enum ManualChangeTestError: Error {
    case failedToCreateUserDefaultsSuite
}
