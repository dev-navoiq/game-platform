# Gathr — Playable Ads

HTML5 playable ad creatives for ad networks. Each playable is a **single self-contained HTML file** (inline CSS + vanilla JS, canvas-drawn art, system fonts, zero network requests) so one file works across networks.

## Playables

| Playable | File | Flow |
|---|---|---|
| Ludo | `ludo/index.html` | ~25 s scripted match: tap to roll → capture a red token → bot moves → tap to roll → march home → win → end card with Install CTA |

## Ad-network spec constraints (why it's built this way)

- **Single file, no external calls.** Meta, AppLovin, and Mintegral all require a self-contained HTML file with no runtime network requests (no CDN fonts, no remote images/JS, no analytics beacons). Everything here is drawn with canvas / CSS / unicode.
- **Size caps.** Meta: ≤ 2 MB (single HTML) / 5 MB zipped assets. AppLovin: ≤ 5 MB. Mintegral: ≤ 5 MB. This creative is well under 100 KB.
- **MRAID.** Networks inject an `mraid` object. The creative:
  - waits for `mraid` `ready` (and viewability) before starting, but runs immediately in a plain browser;
  - uses `mraid.open(url)` for the store click-out, falling back to `window.open(url)`.
- **Interaction rules.** Idle > 4 s shows a tap hint; idle > 8 s auto-advances the script so the ad always completes. After the win, **every** tap opens the store (interaction cap).
- **Orientation.** Portrait-first, responsive to landscape via a canvas resize handler.
- Some networks want variants: ironSource uses its own `dapi` (not MRAID) and Google Ads wants a ZIP with an `ExitApi` — adapt the bootstrap + `openStore()` if targeting those.

## Set the store URLs

At the top of the `<script>` block in `ludo/index.html`:

```js
var IOS_STORE_URL     = 'https://apps.apple.com/app/id0000000000';                 // TODO
var ANDROID_STORE_URL = 'https://play.google.com/store/apps/details?id=com.navoiq.gathr'; // TODO
```

Platform is picked by user agent (`/android/i` → Play Store, otherwise App Store). Some networks (AppLovin, Mintegral) override the click-out URL from their dashboard anyway, but always ship real URLs.

## Test locally

Just open the file in a browser:

```sh
open marketing/playables/ludo/index.html            # macOS
# or serve it (better emulation of webview behavior):
python3 -m http.server -d marketing/playables/ludo 8080   # → http://localhost:8080
```

Use devtools device emulation (iPhone, portrait) for the intended experience; also check landscape. To sanity-check MRAID paths, paste `window.mraid = { getState:()=>'default', open:(u)=>alert('mraid.open: '+u), addEventListener(){}, removeEventListener(){} };` in the console before reload, or upload to a network's playable preview tool (Meta Playable Preview app, AppLovin playable preview).

## QA checklist before uploading

- [ ] Real store URLs set (both platforms)
- [ ] File size under the target network's cap
- [ ] `grep -c 'http' index.html` — only the two store URLs, nothing fetched at runtime
- [ ] Plays through untouched (idle auto-advance) in ≤ ~40 s
- [ ] Every tap after the win opens the store
