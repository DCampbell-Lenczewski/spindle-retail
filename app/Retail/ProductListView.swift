import SwiftUI

/// A list of products with "Buy" buttons. Drop it under your calculator results:
///
///     ProductListView(store: store, spindleSize: 41, source: "calc_result")
///
struct ProductListView: View {
    @ObservedObject var store: ProductStore
    /// Pass the spindle width from the calculator to show only matching parts. nil = show all.
    var spindleSize: Int? = nil
    /// Where the user is in the app; appears in your Awin reports.
    var source: String = "shop_tab"

    @Environment(\.openURL) private var openURL
    @State private var category: String? = nil

    private let categories: [(label: String, value: String?)] = [
        ("All", nil), ("Spindles", "spindles"), ("Handrails", "handrail"),
        ("Baserails", "baserail"), ("Newels", "newel"),
    ]

    var body: some View {
        List {
            Section {
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.label) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.menu)
            }

            Section {
                let items = store.products(category: category, spindleSize: spindleSize)
                if items.isEmpty {
                    Text("No matching products right now.").foregroundStyle(.secondary)
                }
                ForEach(items) { product in
                    ProductRow(product: product, retailer: store.retailerName(for: product)) {
                        guard let catalogue = store.catalogue else { return }
                        openURL(AffiliateLink.url(for: product, in: catalogue, source: source))
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let updated = store.catalogue?.updated {
                        Text("Prices checked \(updated) and may change at checkout.")
                    }
                    // Required in the UK: make it clear these are affiliate links.
                    Text("Ad: we may earn commission when you buy through these links, at no extra cost to you.")
                }
                .font(.footnote)
            }
        }
        .navigationTitle("Buy parts")
        .task { await store.refresh() }
        .refreshable { await store.refresh() }
    }
}

private struct ProductRow: View {
    let product: Product
    let retailer: String
    let onBuy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name).font(.body)
                HStack(spacing: 6) {
                    Text(retailer).fontWeight(.semibold)
                    if let qty = product.packQty, qty > 1 { Text("· pack of \(qty)") }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let price = product.price {
                    Text(price, format: .currency(code: "GBP")).font(.headline)
                }
            }
            Spacer()
            Button("Buy", action: onBuy)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }
}
