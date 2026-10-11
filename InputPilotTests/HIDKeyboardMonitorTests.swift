import IOKit.hid
import Testing
@testable import InputPilot

struct HIDKeyboardMonitorTests {
    @Test(arguments: Array(UInt32(kHIDUsage_KeyboardLeftControl)...UInt32(kHIDUsage_KeyboardRightGUI)))
    func modifierUsagesAreModifiers(usage: UInt32) {
        #expect(HIDKeyboardMonitor.isModifierUsage(usage))
    }

    // 0x3F is F6 on the keyboard usage page. Fn/Globe never arrives on that
    // page (it uses Apple's vendor page), so it needs no entry here.
    @Test(arguments: [
        UInt32(kHIDUsage_KeyboardF6),
        UInt32(kHIDUsage_KeyboardA),
        UInt32(kHIDUsage_KeyboardTab)
    ])
    func regularKeysAreNotModifiers(usage: UInt32) {
        #expect(!HIDKeyboardMonitor.isModifierUsage(usage))
    }
}
