#!/usr/bin/env python3
"""
Create Gathr's in-app purchases + subscriptions in App Store Connect.

Idempotent: products that already exist (by productId) are skipped, and each
sub-step (localization, price, availability) is skipped if already present.

Prereqs: ~/.appstoreonnect/AuthKey_<KEYID>.p8 (App Manager role),
         pip3 install pyjwt cryptography requests

Usage:  python3 scripts/asc/create_iap_products.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from asc_api import get, post, patch, APP_ID  # noqa: E402

REVIEW_NOTE = (
    "Gathr is a social card-game platform. Gems are an in-game currency used "
    "to buy cosmetic card skins and room themes. Subscriptions remove ads and "
    "grant a monthly coin/gem allowance. Sign in with any account; the Shop tab "
    "shows all products."
)

CONSUMABLES = [
    # productId, name (ref + display), description, USD price
    ("com.navoiq.gathr.gems_100",  "Starter Pack",  "100 gems",                     "0.99"),
    ("com.navoiq.gathr.gems_500",  "Popular Pack",  "500 gems + 125 bonus gems",    "3.99"),
    ("com.navoiq.gathr.gems_1200", "Value Pack",    "1200 gems + 600 bonus gems",   "7.99"),
    ("com.navoiq.gathr.gems_3000", "Premium Pack",  "3000 gems + 2250 bonus gems",  "19.99"),
    ("com.navoiq.gathr.gems_7500", "Ultimate Pack", "7500 gems + 7500 bonus gems",  "49.99"),
]

GROUP_NAME = "Gathr Membership"
# Subscription description is capped at 45 characters by App Store Connect.
SUBSCRIPTIONS = [
    # productId, name, description, USD price, groupLevel (1 = highest tier)
    ("com.navoiq.gathr.max_monthly", "Max Membership",
     "All Pro perks + 2,500 coins & 300 gems/mo", "7.99", 1),
    ("com.navoiq.gathr.pro_monthly", "Pro Membership",
     "No ads + 800 coins & 80 gems every month", "3.99", 2),
]

LOCALE = "en-US"


def all_territory_ids():
    return [t["id"] for t in get("/v1/territories", limit=200)]


# ── Consumables ──────────────────────────────────────────────────────────────

def ensure_consumable(product_id, name, description, price_usd, territories):
    existing = {i["attributes"]["productId"]: i for i in get(f"/v1/apps/{APP_ID}/inAppPurchasesV2")}
    if product_id in existing:
        iap = existing[product_id]
        print(f"  = {product_id} exists ({iap['attributes']['state']})")
    else:
        iap = post("/v2/inAppPurchases", {"data": {
            "type": "inAppPurchases",
            "attributes": {
                "name": name,
                "productId": product_id,
                "inAppPurchaseType": "CONSUMABLE",
                "reviewNote": REVIEW_NOTE,
            },
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }})["data"]
        print(f"  + created {product_id} ({iap['id']})")
    iid = iap["id"]

    # Localization
    locs = get(f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations")
    if not any(l["attributes"]["locale"] == LOCALE for l in locs):
        post("/v1/inAppPurchaseLocalizations", {"data": {
            "type": "inAppPurchaseLocalizations",
            "attributes": {"name": name, "description": description, "locale": LOCALE},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}},
        }})
        print(f"    + localization {LOCALE}")

    # Price schedule (USA base territory, manual price = USD price point)
    sched = get(f"/v2/inAppPurchases/{iid}/iapPriceSchedule")
    if sched.get("data"):
        print("    = price schedule exists")
    else:
        points = get(f"/v2/inAppPurchases/{iid}/pricePoints", **{"filter[territory]": "USA", "limit": 200})
        pp = next((p for p in points if p["attributes"]["customerPrice"] == price_usd), None)
        if not pp:
            raise SystemExit(f"No USA price point {price_usd} for {product_id}; have: "
                             f"{sorted(p['attributes']['customerPrice'] for p in points)[:40]}")
        post("/v1/inAppPurchasePriceSchedules", {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price1}"}]},
                },
            },
            "included": [{
                "type": "inAppPurchasePrices",
                "id": "${price1}",
                "attributes": {"startDate": None},
                "relationships": {
                    "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pp["id"]}},
                },
            }],
        })
        print(f"    + price ${price_usd} (USA base, auto-equalized worldwide)")

    # Availability
    avail = get(f"/v2/inAppPurchases/{iid}/inAppPurchaseAvailability")
    if avail.get("data"):
        print("    = availability exists")
    else:
        post("/v1/inAppPurchaseAvailabilities", {"data": {
            "type": "inAppPurchaseAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]},
            },
        }})
        print(f"    + available in {len(territories)} territories")


# ── Subscriptions ────────────────────────────────────────────────────────────

def ensure_group():
    groups = get(f"/v1/apps/{APP_ID}/subscriptionGroups")
    g = next((g for g in groups if g["attributes"]["referenceName"] == GROUP_NAME), None)
    if g:
        print(f"  = group '{GROUP_NAME}' exists ({g['id']})")
    else:
        g = post("/v1/subscriptionGroups", {"data": {
            "type": "subscriptionGroups",
            "attributes": {"referenceName": GROUP_NAME},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }})["data"]
        print(f"  + created group '{GROUP_NAME}' ({g['id']})")
    gid = g["id"]
    locs = get(f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations")
    if not any(l["attributes"]["locale"] == LOCALE for l in locs):
        post("/v1/subscriptionGroupLocalizations", {"data": {
            "type": "subscriptionGroupLocalizations",
            "attributes": {"name": GROUP_NAME, "locale": LOCALE},
            "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}},
        }})
        print(f"    + group localization {LOCALE}")
    return gid


def ensure_subscription(gid, product_id, name, description, price_usd, level, territories):
    subs = get(f"/v1/subscriptionGroups/{gid}/subscriptions")
    s = next((s for s in subs if s["attributes"]["productId"] == product_id), None)
    if s:
        print(f"  = {product_id} exists ({s['attributes']['state']})")
    else:
        s = post("/v1/subscriptions", {"data": {
            "type": "subscriptions",
            "attributes": {
                "name": name,
                "productId": product_id,
                "subscriptionPeriod": "ONE_MONTH",
                "groupLevel": level,
                "reviewNote": REVIEW_NOTE,
            },
            "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": gid}}},
        }})["data"]
        print(f"  + created {product_id} ({s['id']})")
    sid = s["id"]

    locs = get(f"/v1/subscriptions/{sid}/subscriptionLocalizations")
    if not any(l["attributes"]["locale"] == LOCALE for l in locs):
        post("/v1/subscriptionLocalizations", {"data": {
            "type": "subscriptionLocalizations",
            "attributes": {"name": name, "description": description, "locale": LOCALE},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}},
        }})
        print(f"    + localization {LOCALE}")

    # Availability MUST be created before price — ASC rejects
    # subscriptionPrices with ENTITY_ERROR.RELATIONSHIP.INVALID on a
    # subscription that has no availableTerritories yet.
    avail = get(f"/v1/subscriptions/{sid}/subscriptionAvailability")
    if avail.get("data"):
        print("    = availability exists")
    else:
        post("/v1/subscriptionAvailabilities", {"data": {
            "type": "subscriptionAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sid}},
                "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]},
            },
        }})
        print(f"    + available in {len(territories)} territories")

    prices = get(f"/v1/subscriptions/{sid}/prices", **{"filter[territory]": "USA"})
    if prices:
        print("    = USA price exists")
    else:
        points = get(f"/v1/subscriptions/{sid}/pricePoints", **{"filter[territory]": "USA", "limit": 900})
        pp = next((p for p in points if p["attributes"]["customerPrice"] == price_usd), None)
        if not pp:
            raise SystemExit(f"No USA price point {price_usd} for {product_id}")
        post("/v1/subscriptionPrices", {"data": {
            "type": "subscriptionPrices",
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sid}},
                "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp["id"]}},
                "territory": {"data": {"type": "territories", "id": "USA"}},
            },
        }})
        print(f"    + price ${price_usd}/month (USA)")


if __name__ == "__main__":
    territories = all_territory_ids()
    print(f"Territories: {len(territories)}")
    print("── Consumables ──")
    for pid, name, desc, price in CONSUMABLES:
        ensure_consumable(pid, name, desc, price, territories)
    print("── Subscriptions ──")
    gid = ensure_group()
    for pid, name, desc, price, level in SUBSCRIPTIONS:
        ensure_subscription(gid, pid, name, desc, price, level, territories)
    print("Done.")
