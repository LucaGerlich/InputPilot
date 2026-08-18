import Foundation

struct KeyboardFingerprint: Codable, Hashable {
    let vendorId: Int?
    let productId: Int?
    let transport: String?
    let isBuiltIn: Bool
    let productName: String?
    let locationId: Int?

    init(
        vendorId: Int?,
        productId: Int?,
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

    // Devices without VID, PID, and product name are indistinguishable from each
    // other; they must never share identity via primary-fingerprint matching.
    var hasHardwareIdentity: Bool {
        vendorId != nil || productId != nil || normalizedProductName != nil
    }

    var primaryIdentifier: String {
        // Keep this format byte-identical for devices with real IDs: it feeds
        // KeyboardDeviceKey.id, which is the persisted mapping sort key.
        let vendorPart = vendorId.map(String.init) ?? "unknown"
        let productPart = productId.map(String.init) ?? "unknown"
        let transportPart = normalizedTransport ?? "unknown"
        let productNamePart = normalizedProductName ?? "unknown"
        return "\(vendorPart)-\(productPart)-\(transportPart)-\(isBuiltIn ? "builtin" : "external")-\(productNamePart)"
    }

    func matchesPrimary(of other: KeyboardFingerprint) -> Bool {
        guard hasHardwareIdentity, other.hasHardwareIdentity else {
            return false
        }

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

    static func hardwareIdLabel(_ value: Int?) -> String {
        value.map(String.init) ?? "unknown"
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
