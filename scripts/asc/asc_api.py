"""Tiny App Store Connect API client. Usage: from asc import get, post, patch, delete, APP_ID"""
import glob, os, time, jwt, requests
ISSUER = "f29c17c7-d3cc-4177-8ea5-fb36283b5f56"
KEY_PATH = glob.glob(os.path.expanduser("~/.appstoreonnect/AuthKey_*.p8"))[0]
KID = os.path.basename(KEY_PATH)[8:-3]
APP_ID = "6773972441"
BASE = "https://api.appstoreconnect.apple.com"
def _token():
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
                      open(KEY_PATH).read(), algorithm="ES256", headers={"kid": KID})
def _h(): return {"Authorization": f"Bearer {_token()}", "Content-Type": "application/json"}
def _check(r, allow_404=False):
    if r.status_code == 404 and allow_404:
        return {}
    if not r.ok:
        raise SystemExit(f"{r.request.method} {r.url} -> {r.status_code}\n{r.text[:1500]}")
    return r.json() if r.text else {}
def get(path, **params):
    """GET a collection (returns a list) or a to-one relationship (returns a
    dict; {} if the related resource doesn't exist yet, e.g. no price schedule
    set up — ASC returns 404 rather than an empty relationship for those)."""
    url = path if path.startswith("http") else BASE + path
    out = []
    while url:
        j = _check(requests.get(url, headers=_h(), params=params), allow_404=True); params = {}
        if not j:
            return {}
        if "data" in j and isinstance(j["data"], list):
            out += j["data"]; url = j.get("links", {}).get("next")
        else:
            return j
    return out
def post(path, body):   return _check(requests.post(BASE + path, headers=_h(), json=body))
def patch(path, body):  return _check(requests.patch(BASE + path, headers=_h(), json=body))
def delete(path):       return _check(requests.delete(BASE + path, headers=_h()))
