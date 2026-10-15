import SwiftUI

struct CartView: View {
    @EnvironmentObject private var session: Session
    @State private var showingCheckout = false

    private var lines: [(product: Product, qty: Int)] {
        Catalog.products.compactMap { product in
            guard let qty = session.cart[product.id] else { return nil }
            return (product, qty)
        }
    }

    var body: some View {
        Group {
            if lines.isEmpty {
                ContentUnavailableView("Your cart is empty", systemImage: "cart")
                    .accessibilityIdentifier(A11y.Cart.empty)
            } else {
                List {
                    ForEach(lines, id: \.product.id) { line in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(line.product.name).font(.headline)
                                Text("Qty \(line.qty)").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove") { session.remove(line.product.id) }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier(A11y.Cart.removeButton(line.product.id))
                        }
                    }

                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(session.subtotal.currency)
                            .accessibilityIdentifier(A11y.Cart.subtotal)
                    }

                    Button("Checkout") { showingCheckout = true }
                        .accessibilityIdentifier(A11y.Cart.checkout)
                }
                .accessibilityIdentifier(A11y.Cart.list)
            }
        }
        .navigationTitle("Cart")
        .navigationDestination(isPresented: $showingCheckout) { CheckoutView() }
    }
}
