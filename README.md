# Spindle Spacer: retailer links

Shows stair parts from UK retailers in the app, with tracked links that earn commission.

```
products.json                  ← the product list the app reads (start: 12 real Wickes / B&Q items)
app/Retail/                    ← Swift files to drop into your Xcode project
  Catalogue.swift              ← describes the shape of products.json
  AffiliateLink.swift          ← turns a product into a commission-earning link
  ProductStore.swift           ← downloads products.json, caches it, works offline
  ProductListView.swift        ← the "Buy parts" screen
feed-builder/                  ← stage 2: builds products.json automatically every night
  build_products.py
  feeds.config.json
.github/workflows/update-products.yml  ← runs the feed builder nightly on GitHub (free)
test/sample_wickes_feed.csv    ← fake feed for testing the builder
```

## Stage 1: launch with the hand-made list

1. **Put products.json online.** Easiest: create a free GitHub repo, upload this whole folder,
   then open products.json on GitHub and tap **Raw**. That address is your `remoteURL`, e.g.
   `https://raw.githubusercontent.com/YOURNAME/spindle-retail/main/products.json`
2. **Add the Swift files** in `app/Retail/` to your Xcode project.
3. **Also add products.json to the app** (drag into Xcode, tick "Copy items" and your app target).
   This is the offline fallback for first launch.
4. **Create the store once** and show the list, e.g. under your calculator results:

   ```swift
   @StateObject private var store = ProductStore(
       remoteURL: URL(string: "https://raw.githubusercontent.com/YOURNAME/spindle-retail/main/products.json")!
   )

   NavigationLink("Buy parts") {
       ProductListView(store: store, spindleSize: 41, source: "calc_result")
   }
   ```

   `spindleSize` filters to parts that fit (pass whatever width the user entered, or `nil` for all).

Until you're approved by Awin, the Buy buttons open the normal product pages (no commission).
Nothing breaks, so you can ship this now.

## When Awin approves you

Edit products.json online (no app update needed):

- `"publisherId"`: your Awin publisher ID (top of your Awin dashboard).
- `"awinMerchantId"` for each retailer: shown on the retailer's programme page in Awin.
  Wickes is filled in as `1563` (check it matches what Awin shows you). Fill in B&Q's when approved.

The app then builds tracked links automatically. Each link also carries the `source` label,
so Awin reports show which screen each sale came from.

**Note on B&Q:** some B&Q listings are "Sold & shipped by" a marketplace seller (e.g. the trade box of
spindles). Check B&Q's Awin terms; marketplace items may pay a different rate or none.

## Stage 2: automatic nightly updates

1. In Awin, open **Toolbox → Create-a-Feed**, choose the retailer, CSV format, and copy the download URL.
   This URL contains your secret API key, so never put it in the app or in a file.
2. In your GitHub repo: **Settings → Secrets and variables → Actions → New secret**:
   `WICKES_FEED_URL` = that URL. Repeat for `BANDQ_FEED_URL`.
3. Put your publisher ID and merchant IDs in `feed-builder/feeds.config.json`.
4. Go to the **Actions** tab → *Update products* → **Run workflow** to test. After that it runs every night.

What the builder does:
- Keeps only stair parts (by keyword; edit `categories` in the config to tune)
- Drops decking/garden/fencing items and anything out of stock
- Works out spindle size, pack quantity and material from the product name
- Caps each category at 25 products per retailer
- If one retailer's feed fails, keeps yesterday's products for it, so the shop never goes empty

Test it locally:

```
python feed-builder/build_products.py --feed-file wickes=test/sample_wickes_feed.csv --output /tmp/test.json
```

## Before you submit to the App Store

- Keep the "Ad: we may earn commission…" line visible (UK ASA/CMA rules).
- Prices in the starter list were checked on 18 Nov 2026. Three items have no price; the app just hides it.
