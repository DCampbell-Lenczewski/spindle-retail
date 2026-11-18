import Foundation

/// Loads the product list. Order of preference:
///   1. Fresh copy from your server (products.json online)
///   2. The last copy downloaded (saved on the phone)
///   3. The copy bundled inside the app (works offline, first launch)
@MainActor
final class ProductStore: ObservableObject {

    @Published private(set) var catalogue: Catalogue?

    /// Where your products.json lives online, e.g. a GitHub raw URL.
    private let remoteURL: URL

    private let cacheURL: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("products.json")

    init(remoteURL: URL) {
        self.remoteURL = remoteURL
        catalogue = Self.decode(try? Data(contentsOf: cacheURL)) ?? Self.loadBundled()
    }

    /// Call when the shop screen appears. Safe to call often; failures keep the old list.
    func refresh() async {
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let fresh = Self.decode(data) else { return }
            catalogue = fresh
            try? data.write(to: cacheURL, options: .atomic)
        } catch {
            // Offline or server down: keep showing what we have.
        }
    }

    /// Products to show, optionally filtered to the user's spindle size and/or a category.
    func products(category: String? = nil, spindleSize: Int? = nil) -> [Product] {
        guard let all = catalogue?.products else { return [] }
        return all.filter { product in
            if let category, product.category != category { return false }
            // Products with no size (e.g. newels, fixings) always show.
            if let spindleSize, let size = product.spindleSize, size != spindleSize { return false }
            return true
        }
    }

    func retailerName(for product: Product) -> String {
        catalogue?.retailers[product.retailer]?.name ?? product.retailer
    }

    // MARK: - Private

    private static func loadBundled() -> Catalogue? {
        guard let url = Bundle.main.url(forResource: "products", withExtension: "json") else { return nil }
        return decode(try? Data(contentsOf: url))
    }

    private static func decode(_ data: Data?) -> Catalogue? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Catalogue.self, from: data)
    }
}
