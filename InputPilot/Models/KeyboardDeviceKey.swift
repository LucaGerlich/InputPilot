import Foundation

struct KeyboardDeviceKey: Hashable, Codable, Identifiable {
    let fingerprint: KeyboardFingerprint
    let locationIdHint: Int?

    private enum CodingKeys: String, CodingKey {
        case fingerprint
        case locationIdHint

        // Legacy v1 shape.
        case vendorId
        case productId
        case transport
        case locationId
        case isBuiltIn
        case productName
    }

    var vendorId: Int {
        fingerprint.vendorId
    }

    var productId: Int {
        fingerprint.productId
    }

    var transport: String? {
        fingerprint.transport
    }

    var isBuiltIn: Bool {
        fingerprint.isBuiltIn
    }

    var productName: String? {
        fingerprint.productName
    }

    var locationId: Int? {
        locationIdHint ?? fingerprint.locationId
    }

    var primaryIdentifier: String {
        fingerprint.primaryIdentifier
    }

    var id: String {
        let locationPart = locationId.map(String.init) ?? "any-location"
        return "\(primaryIdentifier)-\(locationPart)"
    }

    init(
        vendorId: Int,
        productId: Int,
        transport: String?,
        locationId: Int?,
        isBuiltIn: Bool = false,
        productName: String? = nil
    ) {
        self.fingerprint = KeyboardFingerprint(
            vendorId: vendorId,
            productId: productId,
            transport: transport,
            isBuiltIn: isBuiltIn,
            productName: productName,
            locationId: locationId
        )
        self.locationIdHint = locationId
    }

    init(fingerprint: KeyboardFingerprint, locationIdHint: Int?) {
        self.fingerprint = fingerprint
        self.locationIdHint = locationIdHint
    }

    init(device: ActiveKeyboardDevice) {
        self.init(
            fingerprint: device.fingerprint,
            locationIdHint: device.locationId
        )
    }

    func matchesPrimary(of fingerprint: KeyboardFingerprint) -> Bool {
        self.fingerprint.matchesPrimary(of: fingerprint)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let fingerprint = try container.decodeIfPresent(KeyboardFingerprint.self, forKey: .fingerprint) {
            self.fingerprint = fingerprint
            self.locationIdHint = try container.decodeIfPresent(Int.self, forKey: .locationIdHint) ?? fingerprint.locationId
            return
        }

        let vendorId = try container.decode(Int.self, forKey: .vendorId)
        let productId = try container.decode(Int.self, forKey: .productId)
        let transport = try container.decodeIfPresent(String.self, forKey: .transport)
        let locationId = try container.decodeIfPresent(Int.self, forKey: .locationId)
        let isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn)
            ?? Self.inferBuiltIn(transport: transport)
        let productName = try container.decodeIfPresent(String.self, forKey: .productName)

        self.fingerprint = KeyboardFingerprint(
            vendorId: vendorId,
            productId: productId,
            transport: transport,
            isBuiltIn: isBuiltIn,
            productName: productName,
            locationId: locationId
        )
        self.locationIdHint = locationId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fingerprint, forKey: .fingerprint)
        try container.encodeIfPresent(locationIdHint, forKey: .locationIdHint)
    }

    private static func inferBuiltIn(transport: String?) -> Bool {
        guard let normalizedTransport = KeyboardFingerprint.normalizedTransport(transport) else {
            return false
        }

        return normalizedTransport.contains("internal")
            || normalizedTransport == "spi"
            || normalizedTransport == "i2c"
            || normalizedTransport == "ps2"
    }
}
