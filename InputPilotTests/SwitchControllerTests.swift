import Foundation
import Testing
@testable import InputPilot

@MainActor
struct SwitchControllerTests {
    @Test
    func multipleRapidDeviceEventsTriggerSingleSwitch() async {
        let clock = ControlledClock()
        let controller = SwitchController(clock: clock, debounceMilliseconds: 400, cooldownMilliseconds: 1500)

        let deviceA = KeyboardDeviceKey(vendorId: 1, productId: 1, transport: "USB", locationId: 10)
        let deviceB = KeyboardDeviceKey(vendorId: 2, productId: 2, transport: "USB", locationId: 20)

        var decisions: [(KeyboardDeviceKey, String, KeyboardEventKind)] = []
        let onSwitch: SwitchController.SwitchDecisionHandler = { device, targetInputSourceId, trigger in
            decisions.append((device, targetInputSourceId, trigger))
            return true
        }

        controller.evaluateSwitch(
            device: deviceA,
            currentSource: "com.apple.keylayout.German",
            mapping: "com.apple.keylayout.US",
            isAutoSwitchActive: true,
            eventKind: .keyDown(isModifier: true),
            onSwitch: onSwitch
        )
        controller.evaluateSwitch(
            device: deviceB,
            currentSource: "com.apple.keylayout.German",
            mapping: "com.apple.keylayout.French",
            isAutoSwitchActive: true,
            eventKind: .keyDown(isModifier: false),
            onSwitch: onSwitch
        )
        controller.evaluateSwitch(
            device: deviceA,
            currentSource: "com.apple.keylayout.German",
            mapping: "com.apple.keylayout.US",
            isAutoSwitchActive: true,
            eventKind: .keyDown(isModifier: false),
            onSwitch: onSwitch
        )

        #expect(decisions.isEmpty)

        await waitForSleepRegistration()
        clock.advance(by: .milliseconds(400))
        await waitFor { decisions.count == 1 }

        #expect(decisions.count == 1)
        if decisions.count == 1 {
            #expect(decisions[0].0 == deviceA)
            #expect(decisions[0].1 == "com.apple.keylayout.US")
        }
    }

    @Test
    func cooldownPreventsFlipFlopUntilExpired() async {
        let clock = ControlledClock()
        let controller = SwitchController(clock: clock, debounceMilliseconds: 400, cooldownMilliseconds: 1500)

        let deviceA = KeyboardDeviceKey(vendorId: 1, productId: 1, transport: "USB", locationId: 10)
        let deviceB = KeyboardDeviceKey(vendorId: 2, productId: 2, transport: "USB", locationId: 20)

        var decisions: [(KeyboardDeviceKey, String, KeyboardEventKind)] = []
        let onSwitch: SwitchController.SwitchDecisionHandler = { device, targetInputSourceId, trigger in
            decisions.append((device, targetInputSourceId, trigger))
            return true
        }

        controller.evaluateSwitch(
            device: deviceA,
            currentSource: "com.apple.keylayout.German",
            mapping: "com.apple.keylayout.US",
            isAutoSwitchActive: true,
            eventKind: .keyDown(isModifier: false),
            onSwitch: onSwitch
        )
        await waitForSleepRegistration()
        clock.advance(by: .milliseconds(400))
        await waitFor { decisions.count == 1 }

        controller.evaluateSwitch(
            device: deviceB,
            currentSource: "com.apple.keylayout.US",
            mapping: "com.apple.keylayout.German",
            isAutoSwitchActive: true,
            eventKind: .keyDown(isModifier: false),
            onSwitch: onSwitch
        )
        await waitForSleepRegistration()
        clock.advance(by: .milliseconds(400))
        await Task.yield()

        #expect(decisions.count == 1)

        clock.advance(by: .milliseconds(1500))

        controller.evaluateSwitch(
            device: deviceB,
            currentSource: "com.apple.keylayout.US",
            mapping: "com.apple.keylayout.German",
            isAutoSwitchActive: true,
            eventKind: .keyDown(isModifier: false),
            onSwitch: onSwitch
        )
        await waitForSleepRegistration()
        clock.advance(by: .milliseconds(400))
        await waitFor { decisions.count == 2 }

        #expect(decisions.count == 2)
        if decisions.count == 2 {
            #expect(decisions[1].0 == deviceB)
        }
    }

    private func waitFor(
        maxAttempts: Int = 100,
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

    private func waitForSleepRegistration() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }
}

@MainActor
private final class ControlledClock: ClockProviding {
    var now = Date(timeIntervalSince1970: 0)
    private var sleepers: [CheckedContinuation<Void, Error>] = []

    func sleep(for duration: Duration) async throws {
        _ = duration
        try await withCheckedThrowingContinuation { continuation in
            sleepers.append(continuation)
        }
    }

    func advance(by duration: Duration) {
        now = now.addingTimeInterval(Self.timeInterval(for: duration))
        let pendingSleepers = sleepers
        sleepers.removeAll()
        pendingSleepers.forEach { $0.resume(returning: ()) }
    }

    private static func timeInterval(for duration: Duration) -> TimeInterval {
        let components = duration.components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return seconds + attoseconds
    }
}
