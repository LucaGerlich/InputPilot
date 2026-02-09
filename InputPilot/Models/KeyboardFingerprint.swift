import Foundation

struct KeyboardFingerprint: Codable, Hashable {
    let vendorId: Int
    let productId: Int
    let transport: String?
    let isBuiltIn: Bool
    let productName: String?
    let locationId: Int?

    init(
        vendorId: Int,
        productId: Int,
        transport: String?,
        isBuiltIn: Bool,
        productName: String?,
        locationId: Int?
    ) {
        self.vendorId = vendorId
        self.productId = productId
        self.transport = transport
        self.isBuiltIn = isBuiltIn
        self.productName = productName
        self.locationId = locationId
    }

    var normalizedTransport: String? {
        Self.normalizedTransport(transport)
    }

    var normalizedProductName: String? {
        Self.normalizedProductName(productName)
    }

    var primaryIdentifier: String {
        let transportPart = normalizedTransport ?? "unknown"
        let productNamePart = normalizedProductName ?? "unknown"
        return "\(vendorId)-\(productId)-\(transportPart)-\(isBuiltIn ? "builtin" : "external")-\(productNamePart)"
    }

    func matchesPrimary(of other: KeyboardFingerprint) -> Bool {
        let productNameMatches: Bool
        switch (normalizedProductName, other.normalizedProductName) {
        case let (lhsName?, rhsName?):
            productNameMatches = lhsName == rhsName
        default:
            // Treat missing product names as wildcard to keep matching stable
            // when HID metadata varies between events/sessions.
            productNameMatches = true
        }

        return vendorId == other.vendorId
            && productId == other.productId
            && normalizedTransport == other.normalizedTransport
            && isBuiltIn == other.isBuiltIn
            && productNameMatches
    }

    static func normalizedTransport(_ transport: String?) -> String? {
        guard let transport else {
            return nil
        }

        let normalized = transport
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    static func normalizedProductName(_ productName: String?) -> String? {
        guard let productName else {
            return nil
        }

        let normalized = productName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? nil : normalized
    }
}
