import Foundation
import SwiftUI

/// App state. Deliberately simple — this exists to be driven by tests, not to be a reference
/// architecture. What matters for the suite is that every asynchronous step is *genuinely*
/// asynchronous, so the synchronization helpers in the test framework have something real to wait
/// on rather than a façade that resolves instantly.
@MainActor
final class Session: ObservableObject {
    @Published var isSignedIn: Bool
    @Published var cart: [String: Int] = [:]
    @Published var tier: DeliveryTier = .standard
    @Published var tipPercent: Int = 0

    @Published var isAuthenticating = false
    @Published var loginError: String?

    @Published var isPlacingOrder = false
    @Published var checkoutError: String?
    @Published var confirmedOrderNumber: String?

    init() {
        isSignedIn = LaunchConfig.startsSignedIn
        if LaunchConfig.seedsCart {
            cart = ["SPRING-40": 2]
        }
    }

    /// Simulated network latency. Real enough that a test which doesn't wait will fail.
    private var latency: Duration { LaunchConfig.isFast ? .milliseconds(120) : .milliseconds(900) }

    // MARK: - Auth

    func signIn(email: String, password: String) async {
        loginError = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        try? await Task.sleep(for: latency)

        guard email.contains("@") else {
            loginError = "Enter a valid email address"
            return
        }
        guard password.count >= 8 else {
            loginError = "Invalid email or password"
            return
        }

        isSignedIn = true
    }

    // MARK: - Cart

    func add(_ sku: String) { cart[sku, default: 0] += 1 }

    func remove(_ sku: String) {
        guard let count = cart[sku] else { return }
        if count <= 1 { cart.removeValue(forKey: sku) } else { cart[sku] = count - 1 }
    }

    var itemCount: Int { cart.values.reduce(0, +) }

    var subtotal: Decimal {
        cart.reduce(into: Decimal(0)) { total, entry in
            guard let product = Catalog.products.first(where: { $0.id == entry.key }) else { return }
            total += product.price * Decimal(entry.value)
        }
    }

    var tip: Decimal { subtotal * Decimal(tipPercent) / 100 }

    var total: Decimal { subtotal + tier.fee + tip }

    // MARK: - Checkout

    func placeOrder() async {
        checkoutError = nil
        isPlacingOrder = true
        defer { isPlacingOrder = false }

        try? await Task.sleep(for: latency)

        if LaunchConfig.failsCheckout {
            checkoutError = "Payment declined. Try a different card."
            return
        }

        confirmedOrderNumber = "BLU-\(Int.random(in: 100000...999999))"
        cart.removeAll()
    }
}

extension Decimal {
    /// Currency formatting kept in one place, so a test asserting on a price string can rely on it.
    var currency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
}
