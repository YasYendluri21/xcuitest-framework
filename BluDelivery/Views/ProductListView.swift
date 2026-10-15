import SwiftUI

struct ProductListView: View {
    @EnvironmentObject private var session: Session
    @State private var showingCart = false

    var body: some View {
        NavigationStack {
            List(Catalog.products) { product in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(.headline)
                        Text(product.size).font(.subheadline).foregroundStyle(.secondary)
                        Text(product.price.currency).font(.subheadline)
                    }
                    Spacer()
                    Button("Add") { session.add(product.id) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(A11y.Products.addButton(product.id))
                }
                // `.contain` is load-bearing. Putting an identifier on a container makes SwiftUI
                // treat it as a single accessibility element by default, which hides the Add
                // button inside it from both XCUITest and VoiceOver. `.contain` keeps the row
                // addressable while leaving its children individually reachable.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(A11y.Products.row(product.id))
            }
            .accessibilityIdentifier(A11y.Products.list)
            .navigationTitle("Water")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCart = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cart")
                            if session.itemCount > 0 {
                                Text("\(session.itemCount)")
                                    .accessibilityIdentifier(A11y.Products.cartBadge)
                            }
                        }
                    }
                    .accessibilityIdentifier(A11y.Products.cartButton)
                }
            }
            .navigationDestination(isPresented: $showingCart) { CartView() }
        }
    }
}
