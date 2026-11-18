import Foundation

/// Builds the tracked link that earns you commission.
enum AffiliateLink {

    /// - Parameter source: a short label for where in the app the tap came from,
    ///   e.g. "calc_result" or "shop_tab". Shows up in Awin reports as the click ref.
    static func url(for product: Product, in catalogue: Catalogue, source: String) -> URL {
        // 1. The feed builder already gave us a tracked link: just tag the source.
        if let tracked = product.affiliateUrl {
            return adding(clickRef: source, to: tracked)
        }

        // 2. Build an Awin deep link from the plain product URL.
        let publisherId = catalogue.affiliate.publisherId
        guard
            let merchantId = catalogue.retailers[product.retailer]?.awinMerchantId,
            !merchantId.isEmpty,
            !publisherId.isEmpty,
            !publisherId.hasPrefix("YOUR_")
        else {
            // Not approved yet: send them to the plain product page (no commission).
            return product.url
        }

        let query = [
            "awinmid=\(encode(merchantId))",
            "awinaffid=\(encode(publisherId))",
            "clickref=\(encode(source))",
            "ued=\(encode(product.url.absoluteString))",
        ].joined(separator: "&")

        return URL(string: "https://www.awin1.com/cread.php?\(query)") ?? product.url
    }

    // MARK: - Helpers

    private static func adding(clickRef: String, to url: URL) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = (parts.queryItems ?? []).filter { $0.name != "clickref" }
        items.append(URLQueryItem(name: "clickref", value: clickRef))
        parts.queryItems = items
        return parts.url ?? url
    }

    /// Strict encoding so "&", "=", "?" and "/" inside the product URL can't break the link.
    private static func encode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
