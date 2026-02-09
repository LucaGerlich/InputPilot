import Foundation

struct ActiveKeyboardDevice: Equatable {
    let vendorId: Int
    let productId: Int
    let productName: String?
    let transport: String?
    let locationId: Int?
    let isBuiltIn: Bool

    init(
        vendorId: Int,
        productId: Int,
        productName: String?,
        transport: String?,
        locationId: Int?,
        isBuiltIn: Bool = false
    ) {
        self.vendorId = vendorId
        self.productId = productId
        self.productName = productName
        self.transport = transport
        self.locationId = locationId
        self.isBuiltIn = isBuiltIn
    }

    var fingerprint: KeyboardFingerprint {
        KeyboardFingerprint(
            vendorId: vendorId,
            productId: productId,
            transport: transport,
            isBuiltIn: isBuiltIn,
            productName: productName,
            locationId: locationId
        )
    }

    var displayName: String {
        if let productName, !productName.isEmpty {
            return productName
        }

        if isBuiltIn {
            return "Built-in keyboard"
        }

        return "VID \(vendorId), PID \(productId)"
    }
}
