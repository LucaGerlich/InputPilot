import Foundation
import IOKit.hid
#if DEBUG
import OSLog
#endif

final class HIDKeyboardMonitor: HIDKeyboardMonitoring {
    typealias EventCallback = (ActiveKeyboardDevice, KeyboardEventKind) -> Void

    private var manager: IOHIDManager?
    private var onEvent: EventCallback?

    private(set) var isRunning = false
    private(set) var lastStartError: IOReturn?

#if DEBUG
    private let logger = Logger(subsystem: "InputPilot", category: "HIDKeyboardMonitor")
#endif

    @discardableResult
    func start(onEvent: @escaping EventCallback) -> Bool {
        self.onEvent = onEvent

        guard !isRunning else {
            debugLog("Start requested while already running.")
            return true
        }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: Int(kHIDPage_GenericDesktop),
            kIOHIDDeviceUsageKey as String: Int(kHIDUsage_GD_Keyboard)
        ]

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerRegisterInputValueCallback(
            manager,
            Self.inputValueCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue as CFString
        )

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.defaultMode.rawValue as CFString
            )
            lastStartError = openResult
            debugLog("Failed to start HID monitor. IOReturn=\(openResult)")
            return false
        }

        lastStartError = nil
        self.manager = manager
        self.isRunning = true
        debugLog("HID monitor started.")
        return true
    }

    func stop() {
        guard let manager else {
            isRunning = false
            return
        }

        IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue as CFString
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        self.manager = nil
        self.isRunning = false
        self.onEvent = nil
        debugLog("HID monitor stopped.")
    }

    deinit {
        stop()
    }

    private func handleInputValue(_ value: IOHIDValue) {
        guard IOHIDValueGetIntegerValue(value) > 0 else {
            return
        }

        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        guard usagePage == UInt32(kHIDPage_KeyboardOrKeypad) else {
            return
        }
        let usage = IOHIDElementGetUsage(element)

        let device = IOHIDElementGetDevice(element)
        let transport = stringProperty(for: device, key: kIOHIDTransportKey)
        let builtIn = boolProperty(for: device, key: kIOHIDBuiltInKey)
            || isLikelyBuiltIn(transport: transport)
        let activeDevice = ActiveKeyboardDevice(
            vendorId: intProperty(for: device, key: kIOHIDVendorIDKey) ?? 0,
            productId: intProperty(for: device, key: kIOHIDProductIDKey) ?? 0,
            productName: stringProperty(for: device, key: kIOHIDProductKey),
            transport: transport,
            locationId: intProperty(for: device, key: kIOHIDLocationIDKey),
            isBuiltIn: builtIn
        )

        onEvent?(activeDevice, .keyDown(isModifier: isModifierUsage(usage)))
    }

    private func intProperty(for device: IOHIDDevice, key: String) -> Int? {
        guard let number = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber else {
            return nil
        }

        return number.intValue
    }

    private func stringProperty(for device: IOHIDDevice, key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private func boolProperty(for device: IOHIDDevice, key: String) -> Bool {
        guard let number = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber else {
            return false
        }

        return number.boolValue
    }

    private func isLikelyBuiltIn(transport: String?) -> Bool {
        guard let normalizedTransport = KeyboardFingerprint.normalizedTransport(transport) else {
            return false
        }

        return normalizedTransport.contains("internal")
            || normalizedTransport == "spi"
            || normalizedTransport == "i2c"
            || normalizedTransport == "ps2"
    }

    private func isModifierUsage(_ usage: UInt32) -> Bool {
        let leftControl = UInt32(kHIDUsage_KeyboardLeftControl)
        let rightGUI = UInt32(kHIDUsage_KeyboardRightGUI)
        if (leftControl...rightGUI).contains(usage) {
            return true
        }

        // Fn is not consistently exposed; 0x3F is commonly used when present.
        return usage == 0x3F
    }

    private static let inputValueCallback: IOHIDValueCallback = { context, _, _, value in
        guard let context else {
            return
        }

        let monitor = Unmanaged<HIDKeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.handleInputValue(value)
    }

    private func debugLog(_ message: String) {
#if DEBUG
        logger.debug("\(message, privacy: .public)")
#endif
    }

    var lastStartErrorMessage: String? {
        guard let lastStartError else {
            return nil
        }

        switch lastStartError {
        case kIOReturnNotPermitted:
            return "HID monitor start blocked by macOS permissions/sandbox (kIOReturnNotPermitted)."
        case kIOReturnNotPrivileged:
            return "HID monitor start blocked: process is not privileged (kIOReturnNotPrivileged)."
        case kIOReturnNoDevice:
            return "No matching keyboard HID device available."
        default:
            return "HID monitor start failed with IOReturn \(lastStartError)."
        }
    }
}
