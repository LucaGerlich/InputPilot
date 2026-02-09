import Foundation

struct ActiveKeyboardDevice: Equatable {
    let vendorId: Int
    let productId: Int
    let productName: String?
    let transport: String?
    let locationId: Int?
}
