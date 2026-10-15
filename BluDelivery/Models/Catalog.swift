import Foundation

struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    let size: String
    let price: Decimal
}

/// Delivery tiers, mirroring the product this suite is modelled on.
enum DeliveryTier: String, CaseIterable {
    case standard
    case ultra

    var label: String { self == .standard ? "Standard · 4 hours" : "ULTRA indoor · 2 hours" }
    var fee: Decimal { self == .standard ? 4.00 : 5.00 }
}

enum Catalog {
    static let products: [Product] = [
        Product(id: "SPRING-40", name: "Spring Water", size: "40 × 16.9 oz", price: 6.49),
        Product(id: "PURIFIED-32", name: "Purified Water", size: "32 × 16.9 oz", price: 4.99),
        Product(id: "SPARKLING-24", name: "Sparkling Water", size: "24 × 12 oz", price: 8.99)
    ]
}
