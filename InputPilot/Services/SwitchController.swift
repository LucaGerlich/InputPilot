import Foundation

@MainActor
final class SwitchController {
    typealias SwitchDecisionHandler = (_ device: KeyboardDeviceKey, _ targetInputSourceId: String, _ trigger: KeyboardEventKind) -> Bool

    private struct PendingSwitch {
        let device: KeyboardDeviceKey
        var currentSource: String?
        var mapping: String
        var sawNonModifierKeyDown: Bool
    }

    private let clock: ClockProviding
    private let debounceMilliseconds: Int
    private let cooldownMilliseconds: Int

    private var pendingSwitch: PendingSwitch?
    private var debounceTask: Task<Void, Never>?
    private var cooldownUntil: Date?

    init(
        clock: ClockProviding,
        debounceMilliseconds: Int = 400,
        cooldownMilliseconds: Int = 1500
    ) {
        self.clock = clock
        self.debounceMilliseconds = debounceMilliseconds
        self.cooldownMilliseconds = cooldownMilliseconds
    }

    func evaluateSwitch(
        device: KeyboardDeviceKey,
        currentSource: String?,
        mapping: String?,
        isAutoSwitchActive: Bool,
        eventKind: KeyboardEventKind,
        onSwitch: @escaping SwitchDecisionHandler
    ) {
        guard isAutoSwitchActive else {
            reset()
            return
        }

        guard let mapping, !mapping.isEmpty else {
            clearPending(for: device)
            return
        }

        guard mapping != currentSource else {
            clearPending(for: device)
            return
        }

        guard !isInCooldown else {
            return
        }

        if var pendingSwitch, pendingSwitch.device == device {
            pendingSwitch.currentSource = currentSource
            pendingSwitch.mapping = mapping
            pendingSwitch.sawNonModifierKeyDown = pendingSwitch.sawNonModifierKeyDown || eventKind.isNonModifierKeyDown
            self.pendingSwitch = pendingSwitch
            return
        }

        pendingSwitch = PendingSwitch(
            device: device,
            currentSource: currentSource,
            mapping: mapping,
            sawNonModifierKeyDown: eventKind.isNonModifierKeyDown
        )

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else {
                return
            }

            try? await self.clock.sleep(for: .milliseconds(self.debounceMilliseconds))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self.flushPending(onSwitch: onSwitch)
            }
        }
    }

    func reset() {
        debounceTask?.cancel()
        debounceTask = nil
        pendingSwitch = nil
        cooldownUntil = nil
    }

    private var isInCooldown: Bool {
        guard let cooldownUntil else {
            return false
        }

        return clock.now < cooldownUntil
    }

    private func clearPending(for device: KeyboardDeviceKey) {
        guard pendingSwitch?.device == device else {
            return
        }

        pendingSwitch = nil
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func flushPending(onSwitch: @escaping SwitchDecisionHandler) {
        guard let pendingSwitch else {
            return
        }

        self.pendingSwitch = nil
        debounceTask = nil

        guard !isInCooldown else {
            return
        }

        let trigger: KeyboardEventKind = pendingSwitch.sawNonModifierKeyDown
            ? .keyDown(isModifier: false)
            : .deviceStabilized
        let didSwitch = onSwitch(pendingSwitch.device, pendingSwitch.mapping, trigger)
        guard didSwitch else {
            return
        }

        cooldownUntil = clock.now.addingTimeInterval(TimeInterval(cooldownMilliseconds) / 1000.0)
    }
}
