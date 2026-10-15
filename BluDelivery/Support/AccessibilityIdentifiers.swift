import Foundation

/// Accessibility identifiers, shared by the app and the UI test bundle.
///
/// The file is compiled into both targets, so a renamed identifier is a compile error in the tests
/// rather than a selector that silently stops matching at runtime. This is the single highest-value
/// convention in an XCUITest suite: it removes the entire class of failure where a developer
/// renames something and the tests only find out in CI.
public enum A11y {
    public enum Login {
        public static let email = "login.email"
        public static let password = "login.password"
        public static let submit = "login.submit"
        public static let error = "login.error"
        public static let spinner = "login.spinner"
    }

    public enum Products {
        public static let list = "products.list"
        public static let title = "products.title"
        public static let cartButton = "products.cart"
        public static let cartBadge = "products.cart.badge"
        /// Per-row identifier, so a row is addressed by its product rather than its position.
        public static func row(_ sku: String) -> String { "products.row.\(sku)" }
        public static func addButton(_ sku: String) -> String { "products.add.\(sku)" }
    }

    public enum Cart {
        public static let list = "cart.list"
        public static let subtotal = "cart.subtotal"
        public static let checkout = "cart.checkout"
        public static let empty = "cart.empty"
        public static func removeButton(_ sku: String) -> String { "cart.remove.\(sku)" }
    }

    public enum Checkout {
        public static let deliveryStandard = "checkout.delivery.standard"
        public static let deliveryUltra = "checkout.delivery.ultra"
        public static let tipSegment = "checkout.tip"
        public static let total = "checkout.total"
        public static let placeOrder = "checkout.placeOrder"
        public static let spinner = "checkout.spinner"
        public static let confirmation = "checkout.confirmation"
        public static let orderNumber = "checkout.orderNumber"
    }
}
