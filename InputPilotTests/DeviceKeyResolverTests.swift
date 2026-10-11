import Testing
@testable import InputPilot

@MainActor
struct DeviceKeyResolverTests {
    @Test
    func secondKeyboardOfSameModelGetsItsOwnKey() {
        let first = magicKeyboard(at: 100)
        let second = magicKeyboard(at: 200)

        let key = DeviceKeyResolver.canonicalKey(
            for: KeyboardDeviceKey(device: second),
            among: [KeyboardDeviceKey(device: first)],
            connectedDevices: { [first, second] }
        )

        #expect(key == KeyboardDeviceKey(device: second))
    }

    @Test
    func keyboardMovedToAnotherPortKeepsItsKey() {
        let known = KeyboardDeviceKey(device: magicKeyboard(at: 100))
        let moved = magicKeyboard(at: 300)

        let key = DeviceKeyResolver.canonicalKey(
            for: KeyboardDeviceKey(device: moved),
            among: [known],
            connectedDevices: { [moved] }
        )

        #expect(key == known)
    }

    @Test
    func keyboardMovedToAnotherPortKeepsItsKeyWhenADifferentModelTakesTheOldPort() {
        let known = KeyboardDeviceKey(device: magicKeyboard(at: 100))
        let moved = magicKeyboard(at: 300)
        let otherModel = ActiveKeyboardDevice(
            vendorId: 1133,
            productId: 50475,
            productName: "MX Keys",
            transport: "USB",
            locationId: 100
        )

        let key = DeviceKeyResolver.canonicalKey(
            for: KeyboardDeviceKey(device: moved),
            among: [known],
            connectedDevices: { [moved, otherModel] }
        )

        #expect(key == known)
    }

    @Test
    func knownKeyWithoutLocationAlwaysAbsorbsTheSameModel() {
        let known = KeyboardDeviceKey(device: magicKeyboard(at: nil))
        let observed = magicKeyboard(at: 200)

        let key = DeviceKeyResolver.canonicalKey(
            for: KeyboardDeviceKey(device: observed),
            among: [known],
            connectedDevices: { [observed] }
        )

        #expect(key == known)
    }

    @Test
    func oneOfTwoSameModelKeyboardsMovedFoldsIntoTheVacatedKey() {
        let stayed = KeyboardDeviceKey(device: magicKeyboard(at: 100))
        let vacated = KeyboardDeviceKey(device: magicKeyboard(at: 200))
        let moved = magicKeyboard(at: 300)

        let key = DeviceKeyResolver.canonicalKey(
            for: KeyboardDeviceKey(device: moved),
            among: [stayed, vacated],
            connectedDevices: { [magicKeyboard(at: 100), moved] }
        )

        #expect(key == vacated)
    }

    private func magicKeyboard(at locationId: Int?) -> ActiveKeyboardDevice {
        ActiveKeyboardDevice(
            vendorId: 1452,
            productId: 641,
            productName: "Magic Keyboard",
            transport: "USB",
            locationId: locationId
        )
    }
}
