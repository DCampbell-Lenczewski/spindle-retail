import Foundation

/// The whole products.json file.
struct Catalogue: Codable {
    let version: Int
    /// Date the prices were last checked, e.g. "2026-11-18".
    let updated: String
    let affiliate: Affiliate
    /// Keyed by short retailer code, e.g. "wickes", "bandq".
    let retailers: [String: Retailer]
    let products: [Product]
}

struct Affiliate: Codable {
    let network: String
    /// Your Awin publisher (affiliate) ID. Not secret: it appears in every link you share.
    let publisherId: String
}

struct Retailer: Codable {
    let name: String
    /// The retailer's Awin advertiser ID ("awinmid"). Empty until you're approved.
    let awinMerchantId: String?
}

/// One product shown in the app.
struct Product: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    /// Matches a key in `Catalogue.retailers`.
    let retailer: String
    /// Plain product page on the retailer's site.
    let url: URL
    /// Ready-made tracked link (the nightly feed builder fills this in). Optional.
    let affiliateUrl: URL?
    let price: Double?
    let packQty: Int?
    /// "spindles", "handrail", "baserail", "newel", "fixings", "kit" …
    let category: String
    /// Spindle width in mm this product is for (41, 32, 13 …), if relevant.
    let spindleSize: Int?
    let material: String?
    let imageUrl: URL?
}
