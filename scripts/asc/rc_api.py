"""Tiny RevenueCat v2 Developer API client."""
import os
import requests

SECRET_KEY = os.environ.get("RC_V2_SECRET_KEY", "")
BASE = "https://api.revenuecat.com/v2"


def _h():
    if not SECRET_KEY:
        raise SystemExit("Set RC_V2_SECRET_KEY env var to your RevenueCat v2 secret key")
    return {"Authorization": f"Bearer {SECRET_KEY}", "Content-Type": "application/json"}


def _check(r):
    if not r.ok:
        raise SystemExit(f"{r.request.method} {r.url} -> {r.status_code}\n{r.text[:1500]}")
    return r.json() if r.text else {}


def get(path, **params):
    url = path if path.startswith("http") else BASE + path
    out = []
    while url:
        j = _check(requests.get(url, headers=_h(), params=params))
        params = {}
        if isinstance(j.get("items"), list):
            out += j["items"]
            url = j.get("next_page")
        else:
            return j
    return out


def post(path, body):
    return _check(requests.post(BASE + path, headers=_h(), json=body))


def patch(path, body):
    return _check(requests.patch(BASE + path, headers=_h(), json=body))


def delete(path):
    return _check(requests.delete(BASE + path, headers=_h()))
