# 28 — Ads & Acquisition Plan

**Status:** Proposal (2026-07-07) — not yet locked.
**Scope:** (A) In-app ad monetization for free-tier users, designed to nudge toward Pro/Max. (B) Advert creatives *for* the app (user acquisition), including the playable-ad idea.

---

## Part A — In-app ads (monetize free tier, nudge to Pro)

### What already exists (don't rebuild)

| Piece | State | Where |
|---|---|---|
| Placements enum (banner / interstitial / rewarded / native) | ✅ Designed | `packages/monetization/lib/src/models/ad_placement.dart` |
| Frequency caps + fatigue logic (5 rewarded/day, 20 min cooldown, 30 coins/ad, 30 min fatigue pause) | ✅ Designed | `packages/monetization/lib/src/services/ad_service.dart` |
| Tier gating (`showAdsProvider` → Free sees ads, Pro/Max don't) | ✅ Implemented | `apps/flutter_app/lib/core/di/monetization_providers.dart:123` |
| Interstitial overlay with "Remove ads with Pro" upsell button | ✅ Implemented | `apps/flutter_app/lib/shared/widgets/interstitial_ad_overlay.dart` |
| Lobby banner slot | ✅ Placeholder widget | `apps/flutter_app/lib/shared/widgets/banner_ad_widget.dart` |
| Real ad SDK | ❌ `MockAdPlatform` everywhere | `monetization_providers.dart:47` |
| Ad repository (impressions, coin credit) | ❌ All `UnimplementedError` | `apps/flutter_app/lib/features/shop/data/supabase_ad_repository.dart` |
| AdMob app IDs | ❌ Google universal **test** IDs | `AndroidManifest.xml:42`, `ios/Runner/Info.plist:27` |

### Placement strategy (free tier only)

1. **Game-end interstitial** — the workhorse. Fires on the result screen, *never* mid-game. Frequency: every 2nd game finished, hard cap 1 per 3 minutes.
2. **Rewarded video (opt-in)** — the goodwill + highest-eCPM unit:
   - "Double your coins" on the game-result screen (pairs with `record_game_completion`, the Phase-0 economy prerequisite from the tournament design — rewards must exist before doubling them).
   - "2× daily bonus" on the daily-bonus claim.
   - "Extra reroll" where tier benefits already meter rerolls.
   - Keep the existing caps (5/day, 20 min cooldown).
3. **Lobby native ad** — replace the banner placeholder with a **native ad styled to Refined Crystal** (glass card, felt-green surround). A stock 320×50 banner will look terrible against the design system and earns the least. Ship native later; it's polish, not revenue-critical.
4. **House ads (the nudge engine)** — every 3rd interstitial slot serves our own full-screen Pro upsell instead of a paid ad. Costs nothing, converts better than AdMob pays.

### The nudge ladder (annoyance → conversion, without churn)

- **Tenure ramp:** D0–D2 users see *no* interstitials (retention first — a player who churns on day 1 converts at 0%). D3–D6: every 3rd game. D7+: every 2nd game. Store the ramp in a remote-config table so it's tunable without a release.
- **Every interstitial close** shows the existing "Remove ads with Pro — $3.99/mo" chip for 2s before dismissing.
- **Paywall stat:** surface "You've sat through **N ads** this week" on the subscription screen. Concrete, honest, and the single most persuasive line you can put there.
- **Contrast moments:** after a rewarded ad completes, show "Pro members get 800 coins daily — no ads needed."
- **Hard lines (don't cross):** never mid-game or mid-turn; never during onboarding; never stack interstitial + rewarded back-to-back; respect the fatigue pause already coded. Aggressive beyond this trades subscription revenue for pennies of ad revenue and churns the exact users most likely to convert.

### Engineering work (Phase 1 — revenue live)

1. Add `google_mobile_ads` to `packages/monetization`; implement a `GoogleAdPlatform` behind the existing `AdPlatform` interface (mock stays for tests).
2. Create real AdMob apps (iOS + Android) under the navoiq account; replace test app IDs; keep test *unit* IDs in dev/staging via `env_config.dart`.
3. **Rewarded coin credit must be server-side.** Per the security audit (clients must never self-credit currency), use AdMob **Server-Side Verification (SSV)**: AdMob calls a new `grant-rewarded-coins` edge function with a signed payload; the function verifies the signature and credits 30 coins. The client `claimRewardedAdReward()` path becomes display-only.
4. Implement `SupabaseAdRepository` (impressions table for caps/analytics; credit via the edge function only).
5. Consent & compliance: Google UMP consent flow (GDPR/DMA), iOS ATT prompt (or ship non-personalized ads and skip ATT initially), and **block gambling ad categories in AdMob** — default inventory in India serves real-money rummy/teen-patti ads, which competes with us and risks store policy for a broad-audience board-game app.

### Phase 2 — nudge optimization

Remote-config ad frequency table, tenure ramp, paywall ad-count stat, house-ad rotation, A/B the interstitial cadence (every 2nd vs 3rd game) against D7 retention + Pro conversion.

---

## Part B — Adverts *for* the app (UA)

### Verdict on the playable-ad idea

**Yes for Ludo, no for 29 — and it's a mini web build, not the Flutter app.**

Reality check: playable ads on every network (Meta, Google App Campaigns, Unity, AppLovin, Mintegral) are a **single self-contained HTML5 file, ~2–5 MB, no network calls**. A Flutter web build can't fit (CanvasKit alone blows the budget). But our game logic is pure Dart, so there's a clever middle path:

- `packages/game_ludo` + `packages/bot_strategies` compile with `dart compile js` to a small JS bundle (logic only, likely well under 500 KB minified).
- Hand-rolled canvas renderer on top (simple board + tokens; the scooter presentation layer stays app-only as the "install to see this" hook).

**Playable design (industry-standard shape, 20–30 s):**
1. Board opens mid-game, user's token one dice-roll from capturing an opponent.
2. Tap dice → move → **capture** (scripted to guarantee the dopamine hit; bots make 1–2 quick moves between).
3. Second roll → token reaches home → confetti → "Play the full game — real players, voice chat" → store CTA.
4. Any inactivity ≥3 s or 4th interaction → auto-CTA. End card always reachable.

**Why not 29 as a playable:** trick-taking with bidding and hidden trump can't be taught in 30 seconds to someone who doesn't know it — and anyone who *does* know it doesn't need the tutorial. For 29, the right creative is **video** targeted at the audience that already plays it (Bengal/Bangladesh + diaspora): 15 s of real gameplay, "finally, 29 online with your friends."

### Creative & channel plan

1. **Video creatives first (cheapest, this month):** the recorded-UI pipeline on the self-hosted runner already produces gameplay video. Cut 15–30 s verticals per game for Meta/TikTok/YouTube Shorts. Ludo = broad India/South Asia/MENA; 29 = laser-targeted diaspora interest groups.
2. **Ludo playable second:** prototype hand-rolled HTML5 (or a tool like Luna) with *scripted* moves before investing in the dart2js real-engine version. Networks: Meta, Google App Campaigns, AppLovin/Mintegral (playable-heavy, strong in South Asia).
3. **Web landing playable (`gathr.app/play`):** same HTML5 unit without ad-network size limits — this is also the natural target for the social share-links from the social design (friend invite → play 3 moves in browser → install).
4. **ASO baseline before paid spend:** screenshots per game, "Ludo, 29, Chess & more with friends" positioning, localized store listings (hi-IN, bn-BD).

### Dependency note

The playable does **not** depend on in-app offline bot play (it's standalone HTML5). But a first-session "play Ludo vs bots offline" mode in the app is worth building anyway — it's the landing experience the playable ad promises, and today bots only work through Supabase rooms (`bot_move_controller.dart` sends every bot move to an edge function). Tracked as a separate work item.

---

## Sequencing

| Phase | What | Why first |
|---|---|---|
| 1 | AdMob SDK + game-end interstitial + rewarded w/ SSV edge fn + consent | Revenue + the nudge engine; most scaffolding exists |
| 2 | Tenure ramp, remote-config frequency, paywall ad-count, house ads | Conversion optimization on live data |
| 3 | Video UA creatives via recorded-UI pipeline + ASO | Cheapest UA, no new engineering |
| 4 | Ludo HTML5 playable (scripted → dart2js engine) + web landing playable | Highest-effort creative, built on proven video learnings |

Prerequisite running alongside: `record_game_completion` (game-end rewards) — rewarded "double coins" has nothing to double until it lands.
