import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject private var session: Session

    var body: some View {
        Form {
            Section("Delivery") {
                Button(DeliveryTier.standard.label) { session.tier = .standard }
                    .accessibilityIdentifier(A11y.Checkout.deliveryStandard)
                    .accessibilityAddTraits(session.tier == .standard ? [.isSelected] : [])

                Button(DeliveryTier.ultra.label) { session.tier = .ultra }
                    .accessibilityIdentifier(A11y.Checkout.deliveryUltra)
                    .accessibilityAddTraits(session.tier == .ultra ? [.isSelected] : [])
            }

            Section("Tip") {
                Picker("Tip", selection: $session.tipPercent) {
                    ForEach([0, 10, 15, 20], id: \.self) { Text("\($0)%").tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(A11y.Checkout.tipSegment)
            }

            Section {
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(session.total.currency)
                        .font(.headline)
                        .accessibilityIdentifier(A11y.Checkout.total)
                }
            }

            if let error = session.checkoutError {
                Text(error).foregroundStyle(.red)
            }

            Button {
                Task { await session.placeOrder() }
            } label: {
                HStack {
                    if session.isPlacingOrder {
                        ProgressView().accessibilityIdentifier(A11y.Checkout.spinner)
                    }
                    Text(session.isPlacingOrder ? "Placing order…" : "Place order")
                }
            }
            .disabled(session.isPlacingOrder)
            .accessibilityIdentifier(A11y.Checkout.placeOrder)
        }
        .navigationTitle("Checkout")
        .navigationDestination(item: $session.confirmedOrderNumber) { number in
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
                Text("Order placed").font(.title.bold())
                Text(number).accessibilityIdentifier(A11y.Checkout.orderNumber)
            }
            // Same container rule as the product row: without `.contain` the VStack collapses
            // into a single element and neither it nor the order number is addressable.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(A11y.Checkout.confirmation)
            .navigationBarBackButtonHidden()
        }
    }
}
