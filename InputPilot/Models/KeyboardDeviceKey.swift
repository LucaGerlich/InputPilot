import Foundation

struct KeyboardDeviceKey: Hashable, Codable, Identifiable {
    let vendorId: Int
    let productId: Int
    let transport: String?
    let locationId: Int?

    var id: String {
        let transportValue = transport ?? "unknown"
        let locationValue = locationId.map(String.init) ?? "unknown"
        return "\(vendorId)-\(productId)-\(transportValue)-\(locationValue)"
    }

    init(vendorId: Int, productId: Int, transport: String?, locationId: Int?) {
        self.vendorId = vendorId
        self.productId = productId
        self.transport = transport
        self.locationId = locationId
    }

    init(device: ActiveKeyboardDevice) {
        self.init(
            vendorId: device.vendorId,
            productId: device.productId,
            transport: device.transport,
            locationId: device.locationId
        )
    }
}
