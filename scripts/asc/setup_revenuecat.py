#!/usr/bin/env python3
"""
Configure Gathr's RevenueCat project: iOS app credentials, products
(mirroring the App Store Connect catalog), and pro/max entitlements.

Idempotent — safe to re-run. Android app creation is a no-op until
PLAY_PACKAGE_NAME / PLAY_SERVICE_ACCOUNT_JSON env vars are provided.

Env vars:
  RC_V2_SECRET_KEY            required — RevenueCat v2 Developer API secret key
  ASC_SHARED_SECRET           required — App-Specific Shared Secret from App Store Connect
  ASC_KEY_PATH                optional — path to the .p8 App Store Connect API key
                               (defaults to the one used by create_iap_products.py)
  PLAY_PACKAGE_NAME           optional — enables Android app creation
  PLAY_SERVICE_ACCOUNT_JSON   optional — path to the Play service-account JSON

Usage:  RC_V2_SECRET_KEY=sk_... python3 scripts/asc/setup_revenuecat.py
"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from rc_api import get, post  # noqa: E402
from asc_api import ISSUER as ASC_ISSUER  # noqa: E402

PROJECT_NAME = "GATHR STAGING"
BUNDLE_ID = "app.navoiq.gameplatform"
ASC_KEY_ID = "8MDL92J6J5"
ASC_KEY_PATH = os.environ.get(
    "ASC_KEY_PATH", os.path.expanduser(f"~/.appstoreonnect/AuthKey_{ASC_KEY_ID}.p8")
)

CONSUMABLES = [
    # store_identifier, display_name
    ("com.navoiq.gathr.gems_100", "Starter Pack"),
    ("com.navoiq.gathr.gems_500", "Popular Pack"),
    ("com.navoiq.gathr.gems_1200", "Value Pack"),
    ("com.navoiq.gathr.gems_3000", "Premium Pack"),
    ("com.navoiq.gathr.gems_7500", "Ultimate Pack"),
]
SUBSCRIPTIONS = [
    # store_identifier, display_name, entitlement lookup_key
    ("com.navoiq.gathr.pro_monthly", "Pro Membership", "pro"),
    ("com.navoiq.gathr.max_monthly", "Max Membership", "max"),
]


def find_project_id():
    for p in get("/projects"):
        if p["name"] == PROJECT_NAME:
            return p["id"]
    raise SystemExit(f"No RevenueCat project named {PROJECT_NAME!r}")


def ensure_ios_app(project_id, shared_secret):
    apps = get(f"/projects/{project_id}/apps")
    app = next(
        (a for a in apps if a["type"] == "app_store" and a["app_store"]["bundle_id"] == BUNDLE_ID),
        None,
    )
    if app:
        print(f"  = iOS app exists ({app['id']})")
    else:
        app = post(f"/projects/{project_id}/apps", {
            "name": "Gathr iOS",
            "type": "app_store",
            "app_store": {"bundle_id": BUNDLE_ID, "shared_secret": shared_secret},
        })
        print(f"  + created iOS app ({app['id']})")

    body = {"app_store": {"shared_secret": shared_secret}}
    if os.path.exists(ASC_KEY_PATH):
        body["app_store"]["subscription_private_key"] = open(ASC_KEY_PATH).read()
        body["app_store"]["subscription_key_id"] = ASC_KEY_ID
        body["app_store"]["subscription_key_issuer"] = ASC_ISSUER
        note = "shared secret + App Store Connect API key"
    else:
        note = "shared secret only (no .p8 found for Server Notifications key)"
    post(f"/projects/{project_id}/apps/{app['id']}", body)
    print(f"    set credentials ({note})")
    return app["id"]


def ensure_product(project_id, app_id, store_identifier, display_name, product_type):
    existing = {p["store_identifier"]: p for p in get(f"/projects/{project_id}/products")}
    if store_identifier in existing:
        p = existing[store_identifier]
        print(f"  = {store_identifier} exists ({p['id']})")
        return p["id"]
    p = post(f"/projects/{project_id}/products", {
        "store_identifier": store_identifier,
        "app_id": app_id,
        "type": product_type,
        "display_name": display_name,
    })
    print(f"  + created {store_identifier} ({p['id']})")
    return p["id"]


def ensure_entitlement(project_id, lookup_key, display_name):
    existing = {e["lookup_key"]: e for e in get(f"/projects/{project_id}/entitlements")}
    if lookup_key in existing:
        print(f"  = entitlement '{lookup_key}' exists ({existing[lookup_key]['id']})")
        return existing[lookup_key]["id"]
    e = post(f"/projects/{project_id}/entitlements", {
        "lookup_key": lookup_key,
        "display_name": display_name,
    })
    print(f"  + created entitlement '{lookup_key}' ({e['id']})")
    return e["id"]


def ensure_attached(project_id, entitlement_id, product_id, label):
    attached = {p["id"] for p in get(f"/projects/{project_id}/entitlements/{entitlement_id}/products")}
    if product_id in attached:
        print(f"    = {label} already attached")
        return
    post(f"/projects/{project_id}/entitlements/{entitlement_id}/actions/attach_products",
         {"product_ids": [product_id]})
    print(f"    + attached {label}")


def main():
    shared_secret = os.environ.get("ASC_SHARED_SECRET")
    if not shared_secret:
        raise SystemExit("Set ASC_SHARED_SECRET to the App-Specific Shared Secret from App Store Connect")

    project_id = find_project_id()
    print(f"Project: {PROJECT_NAME} ({project_id})")

    print("── iOS app ──")
    ios_app_id = ensure_ios_app(project_id, shared_secret)

    play_package = os.environ.get("PLAY_PACKAGE_NAME")
    android_app_id = None
    print("── Android app ──")
    if play_package and os.environ.get("PLAY_SERVICE_ACCOUNT_JSON"):
        raise SystemExit("Android app creation not yet implemented — need Play API schema first")
    else:
        print("  (skipped — set PLAY_PACKAGE_NAME + PLAY_SERVICE_ACCOUNT_JSON to enable)")

    print("── Consumable products (iOS) ──")
    for store_id, name in CONSUMABLES:
        ensure_product(project_id, ios_app_id, store_id, name, "consumable")

    print("── Subscription products (iOS) + entitlements ──")
    for store_id, name, ent_key in SUBSCRIPTIONS:
        product_id = ensure_product(project_id, ios_app_id, store_id, name, "subscription")
        entitlement_id = ensure_entitlement(project_id, ent_key, name)
        ensure_attached(project_id, entitlement_id, product_id, store_id)

    print("Done.")


if __name__ == "__main__":
    main()
