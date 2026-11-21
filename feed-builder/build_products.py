#!/usr/bin/env python3
"""
Builds products.json from Awin product feeds.

Each night (via GitHub Actions) this:
  1. downloads each retailer's Awin feed (URL kept secret in an environment variable),
  2. keeps only stair parts (spindles, handrails, baserails, newels, fixings, kits),
  3. drops out-of-stock and outdoor/decking items,
  4. writes products.json in the format the app reads.

If a retailer's feed fails, its products from the previous products.json are kept,
so one bad night never empties the shop.

Usage:
  python build_products.py                       # real run, feed URLs from env vars
  python build_products.py --feed-file wickes=sample.csv   # test with a local file
"""
import argparse
import csv
import datetime as dt
import gzip
import hashlib
import io
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_CONFIG = HERE / "feeds.config.json"
DEFAULT_OUTPUT = HERE.parent / "products.json"

# Awin feed column names (with fallbacks for slightly different feed setups).
COL = {
    "id":        ["aw_product_id", "merchant_product_id"],
    "name":      ["product_name"],
    "tracked":   ["aw_deep_link"],
    "url":       ["merchant_deep_link"],
    "price":     ["search_price", "store_price", "display_price"],
    "image":     ["merchant_image_url", "aw_image_url"],
    "in_stock":  ["in_stock"],
    "category":  ["merchant_category", "category_name"],
}

SIZE_RE = re.compile(r"\b(13|14|16|20|32|35|41|45)\s*(?:mm|x\b|×)", re.I)
PACK_RE = re.compile(r"(?:pack|box)\s+of\s+(\d+)|(\d+)\s*(?:pack|pk)\b", re.I)
MATERIALS = ["oak", "pine", "hemlock", "ash", "walnut", "metal", "chrome", "glass", "white primed"]


def get(row, key):
    for col in COL[key]:
        value = (row.get(col) or "").strip()
        if value:
            return value
    return ""


def download(url):
    with urllib.request.urlopen(url, timeout=120) as resp:
        raw = resp.read()
    if raw[:2] == b"\x1f\x8b":  # gzip
        raw = gzip.decompress(raw)
    return raw.decode("utf-8-sig", errors="replace")


def classify(name, categories, exclude):
    lower = name.lower()
    if any(word in lower for word in exclude):
        return None
    # Most specific first: a "handrail for 41mm spindles" is a handrail, not a spindle,
    # and a "handrail kit" is a kit.
    priority = ["kit", "fixings", "handrail", "baserail", "newel", "spindles"]
    order = [c for c in priority if c in categories] + [c for c in categories if c not in priority]
    for cat in order:
        if any(word in lower for word in categories.get(cat, [])):
            return cat
    return None


def parse_price(text):
    try:
        return round(float(re.sub(r"[^\d.]", "", text)), 2)
    except ValueError:
        return None


def to_product(row, retailer, categories, exclude):
    name = get(row, "name")
    url = get(row, "url")
    if not name or not url:
        return None
    if get(row, "in_stock") in ("0", "false", "no", "False"):
        return None
    shop_category = get(row, "category").lower()
    if any(word in shop_category for word in exclude):
        return None
    category = classify(name, categories, exclude)
    if not category:
        return None

    product = {
        "id": f"{retailer}-{get(row, 'id') or hashlib.md5(url.encode()).hexdigest()[:10]}",
        "name": name,
        "retailer": retailer,
        "url": url,
        "category": category,
    }
    if tracked := get(row, "tracked"):
        product["affiliateUrl"] = tracked
    if (price := parse_price(get(row, "price"))) is not None:
        product["price"] = price
    if image := get(row, "image"):
        product["imageUrl"] = image
    if size := SIZE_RE.search(name):
        product["spindleSize"] = int(size.group(1))
    pack = PACK_RE.search(name)
    product["packQty"] = int(pack.group(1) or pack.group(2)) if pack else 1
    lower = name.lower()
    for material in MATERIALS:
        if material in lower:
            product["material"] = material.title()
            break
    return product


def build(config, feed_files, previous):
    categories, exclude = config["categories"], config["exclude"]
    cap = config.get("maxPerCategoryPerRetailer", 25)
    products, retailers = [], {}

    for feed in config["feeds"]:
        code = feed["retailer"]
        retailers[code] = {"name": feed["name"], "awinMerchantId": feed.get("awinMerchantId", ""), "searchUrl": feed.get("searchUrl", "")}

        try:
            if code in feed_files:
                text = Path(feed_files[code]).read_text(encoding="utf-8-sig")
            elif os.environ.get(feed["urlEnv"]):
                text = download(os.environ[feed["urlEnv"]])
            else:
                raise RuntimeError(f"no feed: set {feed['urlEnv']}")
            rows = csv.DictReader(io.StringIO(text))
            found, per_cat, seen = [], {}, set()
            for row in rows:
                p = to_product(row, code, categories, exclude)
                if not p or p["url"] in seen:
                    continue
                if per_cat.get(p["category"], 0) >= cap:
                    continue
                seen.add(p["url"])
                per_cat[p["category"]] = per_cat.get(p["category"], 0) + 1
                found.append(p)
            if not found:
                raise RuntimeError("feed had no matching products")
            print(f"{code}: {len(found)} products {per_cat}")
            products.extend(found)
        except Exception as exc:  # keep yesterday's products for this retailer
            kept = [p for p in previous.get("products", []) if p.get("retailer") == code]
            print(f"{code}: FAILED ({exc}); keeping {len(kept)} previous products", file=sys.stderr)
            products.extend(kept)

    products.sort(key=lambda p: (p["category"], p["retailer"], p.get("price") or 0))
    return {
        "version": 1,
        "updated": dt.date.today().isoformat(),
        "affiliate": {"network": "awin", "publisherId": config["publisherId"]},
        "retailers": retailers,
        "products": products,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=DEFAULT_CONFIG)
    ap.add_argument("--output", default=DEFAULT_OUTPUT)
    ap.add_argument("--feed-file", action="append", default=[],
                    help="retailer=path.csv to use a local feed (for testing)")
    args = ap.parse_args()

    config = json.loads(Path(args.config).read_text())
    feed_files = dict(f.split("=", 1) for f in args.feed_file)
    out = Path(args.output)
    previous = json.loads(out.read_text()) if out.exists() else {}

    catalogue = build(config, feed_files, previous)
    if not catalogue["products"]:
        sys.exit("No products at all; not overwriting products.json")
    out.write_text(json.dumps(catalogue, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {len(catalogue['products'])} products to {out}")


if __name__ == "__main__":
    main()
