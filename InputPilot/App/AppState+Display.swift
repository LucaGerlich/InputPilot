import Foundation

/// What the menu and Settings show, phrased for someone who has never heard
/// of a vendor ID. Derived from AppState; holds no state of its own.
extension AppState {
    var permissionLine: String {
        "Input Monitoring: \(status.permissionStatus.displayName)"
    }

    var monitorLine: String {
        guard isKeyboardMonitorRunning else {
            return "Keyboard detection: stopped"
        }

        return monitorHasPartialAccess
            ? "Keyboard detection: running, without a keyboard held by another app"
            : "Keyboard detection: running"
    }

    var activeKeyboardLine: String {
        "Typing on: \(status.activeKeyboard)"
    }

    var activeInputSourceLine: String {
        "Input source: \(status.activeInputSource)"
    }

    var activeKeyboardTitle: String? {
        activeDeviceKey.map(deviceTitle(for:))
    }

    /// The source the keyboard in use switches to, or nil if it has none.
    var activeKeyboardTargetName: String? {
        activeDeviceKey
            .flatMap(resolvedTargetInputSourceId(for:))
            .map(inputSourceName(for:))
    }

    var canUseCurrentSourceForActiveDevice: Bool {
        guard let activeDeviceKey, let currentInputSourceId else {
            return false
        }

        return mappedInputSourceId(for: activeDeviceKey) != currentInputSourceId
            && selectableInputSources.contains(where: { $0.id == currentInputSourceId })
    }

    func deviceTitle(for deviceKey: KeyboardDeviceKey) -> String {
        if let detectedDevice = detectedDevicesByKey[deviceKey] {
            return detectedDevice.displayName
        }

        if let productName = deviceKey.productName, !productName.isEmpty {
            return productName
        }

        if deviceKey.isBuiltIn {
            return "Built-in keyboard"
        }

        return "Keyboard (vendor \(KeyboardFingerprint.hardwareIdLabel(deviceKey.vendorId)), product \(KeyboardFingerprint.hardwareIdLabel(deviceKey.productId)))"
    }

    func deviceSubtitle(for deviceKey: KeyboardDeviceKey) -> String {
        var parts: [String] = []

        if deviceKey.isBuiltIn {
            parts.append("Built-in")
        } else if let transport = deviceKey.transport, !transport.isEmpty {
            parts.append(transport)
        }

        parts.append("Vendor \(KeyboardFingerprint.hardwareIdLabel(deviceKey.vendorId))")
        parts.append("Product \(KeyboardFingerprint.hardwareIdLabel(deviceKey.productId))")

        // The location is meaningless on its own; it only tells two keyboards
        // of the same model apart.
        let twins = knownDeviceKeys.filter { $0.matchesPrimary(of: deviceKey.fingerprint) }
        if twins.count > 1, let locationId = detectedDevicesByKey[deviceKey]?.locationId ?? deviceKey.locationId {
            parts.append("Location \(locationId)")
        }

        return parts.joined(separator: " · ")
    }

    func mappingConflictSourceName(for conflict: MappingConflict) -> String {
        inputSourceName(for: conflict.mappedSourceId)
    }

    func mappingConflictReasonText(for conflict: MappingConflict) -> String {
        conflict.reason.explanation
    }

    /// "Paused until 14:32", with the date when it is not today.
    func pausedUntilText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .medium
        return "Paused until \(formatter.string(from: date))"
    }
}
