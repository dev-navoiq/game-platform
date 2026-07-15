# 27 — Animations Catalog & Roadmap

> A comprehensive inventory of animations that would elevate Gathr, organized by
> surface, with what already exists, what's new, effort estimates, and
> monetization hooks. Companion to `10-animation-system.md` (the built core
> system) and `CARD-ANIMATION-PLAN.md`.
>
> Priority key: **P0** = highest perceived-quality-per-effort, ship next ·
> **P1** = strong polish, schedule soon · **P2** = delight/luxury, backlog.
> Effort: S (< half day) / M (1–2 days) / L (3+ days or needs authored assets).

---

## 0. What already exists (don't rebuild)

Built under `apps/flutter_app/lib/shared/animations/`:

- **Cards**: deal, play (with trail), flip, fan, shuffle, trick-collect
- **Gameplay**: turn indicator (pulse+sweep ring), timer ring, bid counter,
  bidding pulse, trump reveal (particles), score update, shake, Oh-Hell bust
- **Celebrations**: confetti, fireworks, trophy, particle system, winner jump,
  loser sad, doubling burst
- **Social**: emoji bubble, chat message, avatar reaction
- **Transitions**: page, modal, list-item
- **Ludo**: `LudoAnimatedBoard` — diff-driven hop-per-cell drive + crash
  (spin/fade-to-garage) via `LudoRiderSkin` seam (`ScooterSkin`, `ClassicSkin`)

The gaps below are about *wiring existing pieces into more screens*, adding
missing moments, and character/skin identity — not re-inventing the core.

---

## 1. Ludo — character & board (flagship area)

The scooter presentation made Ludo feel alive; this is the surface with the
biggest personality upside and the clearest paid-cosmetics hook.

| # | Animation | Description | Pri | Effort |
|---|-----------|-------------|-----|--------|
| 1.1 | **Rider-visible characters** | New skin family where a rider (helmeted person) is drawn ON the scooter/bike — leaning into corner turns, head-bob while idle. Old rider-less scooter and classic pawn stay as options. **Paid users pick their character** (see §7). | P0 | M |
| 1.2 | Cornering lean | On the 4 diagonal corner steps, bank the vehicle + rider into the turn (rotate ±12°, brief squash). Uses existing heading data from `route()`. | P0 | S |
| 1.3 | Idle life | Tokens waiting in garage/on-cell do subtle engine-idle vibration or rider look-around every few seconds (staggered so it never syncs). | P1 | S |
| 1.4 | Capture drama | Captor does a small wheelie on arrival; victim's crash gets skid-marks decal that fades over ~3s + dust-puff particles. | P0 | M |
| 1.5 | Boost trail on 6 | Rolling a 6 gives that move an exhaust-flame/speed-line trail behind the vehicle. | P1 | S |
| 1.6 | Home-stretch glow | Cells of a player's home column light up sequentially as their token drives up it. | P1 | S |
| 1.7 | Finish celebration | Token reaching center: victory lap around the center triangle → confetti burst (reuse `ConfettiAnimation`) → parks in finish slot with a hop. | P0 | M |
| 1.8 | Dice enhancement | 3D-feel tumble (already partly in `ludo_dice_widget.dart`) + result "stamp" bounce; shake-to-roll haptic on mobile. | P1 | S |
| 1.9 | Blocked-move feedback | Tapping an unmovable token: side-to-side head-shake (reuse `ShakeAnimation`) + dim pulse of legal tokens. | P0 | S |
| 1.10 | Safe-square shield | Landing on a safe square pops a brief translucent shield ring. | P1 | S |
| 1.11 | Rive character upgrade | Author `.riv` riders (blink, tumble, cheer states) and add `RiveRiderSkin` — the seam already exists, zero board changes. | P2 | L |

## 2. Card games (29, Oh Hell, Hearts, Spades, Bridge, Rummy)

| # | Animation | Description | Pri | Effort |
|---|-----------|-------------|-----|--------|
| 2.1 | Card hover/peek | Drag-up peek with spring-back on release; slight fan-spread of neighbors while dragging. | P0 | M |
| 2.2 | Invalid-play shake | Reuse `ShakeAnimation` + red edge-glow when tapping an illegal card. | P0 | S |
| 2.3 | Trump auto-reveal moment | 29's face-down trump auto-reveal (see engine rule) deserves a dramatic flip + freeze-frame ~400ms so players notice WHY it flipped. | P0 | S |
| 2.4 | Trick-winner spotlight | Dim table 30%, spotlight winning card 600ms before trick-collect slide. | P1 | S |
| 2.5 | Last-trick replay ribbon | Mini animated replay of the previous trick in a corner chip on tap. | P2 | M |
| 2.6 | Rummy meld snap | Cards magnetically snap into a valid meld with a satisfying click + brief gold outline. | P1 | M |
| 2.7 | Dealer chip movement | Animated dealer button sliding to the next seat between hands. | P1 | S |
| 2.8 | Score tally cascade | End-of-round: points fly from tricks/melds to the scorecard, counter rolls up (reuse `ScoreUpdateAnimation` + trajectory). | P1 | M |

## 3. Home / navigation / lobby

| # | Animation | Description | Pri | Effort |
|---|-----------|-------------|-----|--------|
| 3.1 | Game-tile idle motifs | Each game card on home gets a tiny looping motif (dice tumble, card flip, pawn hop) — staggered, paused when off-screen. | P1 | M |
| 3.2 | Hero transition into game | Tapping a game tile expands it into the loading screen (Hero + fade), instead of a plain push. | P0 | S |
| 3.3 | Player-join pop | Lobby seats: avatar pops in with scale-overshoot + ring ripple; leave = deflate. | P0 | S |
| 3.4 | Ready-state wave | When all players ready, a wave of green sweeps across the seat ring, then countdown 3-2-1 with number punch-in. | P1 | S |
| 3.5 | Matchmaking radar | Sonar sweep over avatars while searching; found opponent slides in with VS flash. | P1 | M |
| 3.6 | Pull-to-refresh flourish | Custom refresh indicator: felt-green chip spin or mini card shuffle instead of the stock spinner. | P2 | S |
| 3.7 | Glass shimmer on focus | Refined-Crystal panels get a slow specular shimmer sweep on first appearance (once, not looping — battery). | P2 | S |

## 4. Monetization surfaces (shop, coins, season pass)

| # | Animation | Description | Pri | Effort |
|---|-----------|-------------|-----|--------|
| 4.1 | Coin/gem flight | Earning currency: coins arc from source (game result, chest, ad button) to the balance chip, which bumps + rolls up. Single most valuable monetization animation. | P0 | M |
| 4.2 | Purchase success | Gem pack purchase: burst + item card flip-reveal with glow rarity ring. | P1 | S |
| 4.3 | Chest/reward open | Daily reward chest: lid pop, light shafts, items fountain out sequentially. | P1 | M |
| 4.4 | Season-pass progress fill | XP bar fills with liquid easing + tick pops at each reward node; unlocked node does a wobble-glow. | P1 | S |
| 4.5 | Tier-upgrade moment | Subscribing to Pro/Max: full-screen crystal shatter → gold reveal of new benefits, one by one. | P2 | M |
| 4.6 | Skin preview turntable | In shop/picker, characters slowly rotate/drive-in-place so buyers see the animation before buying (see §7 picker). | P0 | S |

## 5. Social & presence

| # | Animation | Description | Pri | Effort |
|---|-----------|-------------|-----|--------|
| 5.1 | Friend-online ripple | Presence dot ripples once when a friend comes online; row slides up in "recent". | P1 | S |
| 5.2 | Typing indicator | Three-dot breathing bubble in DM threads. | P0 | S |
| 5.3 | PTT speaking ring | Voice: speaking player's avatar gets an amplitude-reactive ring (ties into M4 voice work). | P1 | M |
| 5.4 | Party formation | Accepting a party invite: avatars slide together into the party bar with a soft click. | P1 | S |
| 5.5 | Emoji rain escalation | Same emoji sent 3+ times quickly by table → brief screen-edge rain of that emoji (cap intensity, respect reduced-motion). | P2 | S |
| 5.6 | Friend-code share card | The share sheet card assembles itself (code digits flip in like a split-flap display). | P2 | M |

## 6. System-level & feel

| # | Item | Description | Pri | Effort |
|---|------|-------------|-----|--------|
| 6.1 | **Reduced-motion setting** | Global "reduce animations" toggle + respect OS `disableAnimations`; every looping/celebration animation checks it. Accessibility + battery; do this before adding more loops. | P0 | S |
| 6.2 | Haptic vocabulary | Pair key animations with haptics: light (card play), medium (capture), success pattern (win). One `GameHaptics` helper, used everywhere. | P0 | S |
| 6.3 | Skeleton shimmer loading | Replace spinners on list screens with glass-styled skeleton shimmer. | P1 | M |
| 6.4 | Connection-state banner | Reconnecting: subtle pulsing amber top border rather than a modal; snap-back flash on resync. | P1 | S |
| 6.5 | Frame-budget audit | Profile celebrations on low-end Android (Galaxy A16 is the reference device) — particle counts may need device-tier scaling. | P1 | S |

---

## 7. Character skin system (the 1.1 build — shipped with this doc)

**Concept.** `LudoRiderSkin` is already the swap seam. We add a *rider-visible*
skin family and a picker:

- `ClassicSkin` — flat pawn (free)
- `ScooterSkin` — rider-less vector scooter (free, current default)
- **`RiderScooterSkin`** — scooter with visible helmeted rider, lean + head-bob (paid)
- **`RiderBikeSkin`** — sport-bike silhouette with tucked rider (paid)
- Future: `RiveRiderSkin` characters, seasonal riders (paid, rotating)

**Gating.** `TierBenefits.exclusiveSkins` (already true for Pro/Max) gates the
paid family. Free users see the paid options in the picker with a lock + "Pro"
chip (upsell surface); selecting one deep-links to the subscription screen.

**Persistence.** Selected skin id stored per-device via `SharedPreferences`
(cosmetic, no server authority needed now). If it should roam later, add a
`profiles.ludo_skin` column — the provider seam makes that a one-file change.

**Non-goals for the slice**: per-color different characters, shop purchase of
individual skins (that's the `skins` table / SkinService integration, later).

---

## Suggested build order

1. **6.1 + 6.2** (reduced-motion + haptics) — foundation, cheap, unblocks the rest
2. **§7 / 1.1** rider-visible skins + tier-gated picker ← *this session*
3. **4.1** coin flight + **1.7** Ludo finish celebration + **1.4** capture drama
4. **2.1–2.3** card-feel pack, **3.2–3.3** lobby pack
5. Everything P1, then P2 as garnish; **1.11** Rive when `.riv` assets exist
