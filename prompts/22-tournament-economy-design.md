# 22 — Tournament & Economy Design

> Product/economic design layered on top of the tournament **schema** (already built — see
> [18-tournaments.md](18-tournaments.md)) and the **virtual economy** (coins/gems/XP, subscription
> tiers — see [13-monetization-ads.md](13-monetization-ads.md) and [20-product-strategy.md](20-product-strategy.md)).
>
> Status: **DESIGN ONLY — not yet built.** Decisions locked 2026-06-30. This doc is the source of
> truth for *what the rules are*; implementation is phased at the bottom.

---

## 0. Context — what already exists vs. what's missing

The tournament **tables and Flutter data layer are essentially complete**; the **server-side rules
and the surrounding economy loop are not**. Key facts established by codebase audit (2026-06-30):

| System | State |
|---|---|
| Tournament DB: `tournaments`, `tournament_participants`, `tournament_matches`, `tournament_chat` | ✅ Complete — migration `20260310000000_add_tournaments.sql`. Has `organizer_id`, `is_official`, `entry_fee_coins/gems`, `prize_pool` jsonb, `min_subscription_tier`, bracket-advance columns (`next_match_id`, `next_match_slot`, `loser_next_match_id`) |
| Tournament Flutter models / repo / providers / list screen / bracket generator | ✅ Built; `tournament_detail_screen.dart` is **under construction** |
| Currency ledger (`currency_transactions`) + `creditCurrency`/`debitCurrency`/`grantXp` | ✅ `supabase/functions/_shared/currency.ts` |
| Subscription tiers Free/Pro/Max, RevenueCat webhook, monthly grants | ✅ |
| Faucets: daily bonus, challenges, season rewards, referrals, subscription grants | ✅ wired |
| **Game-end rewards** (`record_game_completion()` RPC) | ❌ **defined but never called** — finishing a game awards nothing |
| Tournament server logic: fee debit, bracket gen on start, match→room, result ingestion, payout | ❌ none |
| Flutter currency/season/challenge repositories | ❌ stubbed (`UnimplementedError`); balances real in DB but not surfaced in-app |

**Core insight:** tournaments are an economy feature sitting on a *per-game reward loop that does not
exist yet*. Build the loop first (Phase 0).

---

## 1. Two-currency economy (the foundation)

Standard dual-currency design (cf. Clash Royale gold/gems, Zynga chips/gems, Pogo tokens/gems). Health
comes from balancing **faucets** (sources) against **sinks** (drains).

**Coins — soft currency.** Abundant, earned by playing.
- Faucets: game-end rewards, daily bonus, challenges, low season-pass tiers.
- Sinks: cosmetics, challenge rerolls, **casual tournament entry**.

**Gems — hard currency.** Scarce, mostly *purchased* with money.
- Faucets: small daily streak, season pass, rare challenges, IAP packs.
- Sinks: premium cosmetics, season pass, **premium tournament entry + platform rake**.

### 1.1 The missing faucet — game-end rewards (Phase 0, do first)
- Call the existing `record_game_completion()` at game end — in `validate-move/index.ts`, where room
  status already flips to `finished`.
- Grant: **win ≈ 40 coins, loss ≈ 12 coins** (participation), both with XP, scaled mildly by game
  length. **First-win-of-day bonus ≈ 100 coins.** Apply diminishing returns / soft daily cap to kill
  bot-farming.
- Push XP into **both** global level and active season (the `addSeasonXp` helper already does this for
  challenges) — this is what makes the season pass tick.
- Wire `game_over_dialog.dart` to the real numbers (it already accepts `coinsEarned`/`xpEarned`).

Without this faucet the gem/coin sinks below have nothing to balance against.

---

## 2. Who can host a tournament?

Two classes, anticipated by the existing `is_official` + `organizer_id` columns.

### 2.1 Official tournaments (`is_official = true`, system-owned)
The always-on supply. Daily/weekly, platform-funded pools, free or cheap coin entry. This is what the
vast majority of players engage with (cf. Clash Royale Global Tournaments, Chess.com daily arenas).
**Supply is the product** — players need something joinable at any hour.

### 2.2 Community tournaments (`is_official = false`, `organizer_id = user`)
**DECISION (locked): hosting is a paid feature — Pro/Max only. Free users can join, never host.**
This makes hosting a clean subscription lever (aligns with the "friends-room-only paywall is the next
lever" strategy) and minimizes the abuse surface.

| Tier | Hosting rights |
|---|---|
| **Free** | ❌ Cannot host. Joins official + community tournaments only. |
| **Pro** | Public community tournaments, up to ~16 players, coin pools + capped gem pools. |
| **Max** | Large community tournaments (32+), full gem pools, custom formats, recurring/scheduled. |

The `min_subscription_tier` column additionally enables **Pro/Max-exclusive tournaments** (higher
pools) as a subscriber perk on the *join* side.

---

## 3. Money model — virtual only, with an off-platform boundary

### 3.1 Hard rule: the platform is never a money-transmitter
**DECISION (locked): all on-platform entries and prizes are virtual (coins/gems) and non-redeemable.
We never take real cash in as a stake, and never pay real cash out.** This keeps the product a *game*,
not a betting platform — avoiding RMG licensing (India RMG litigation, US state-by-state skill-gaming
law) and app-store gambling policies.

### 3.2 Off-platform real-money settlement (the nuance)
Some community organizers may want to award **real cash prizes that they fund and settle entirely
off-platform** (e.g., a creator running a cash bracket for their audience). The platform may provide
the *bracket/organization tooling* for this, but must **sever any link between purchasable currency
and the prize**, or it becomes the thing that converts money → prize (i.e., gambling).

Mechanism — a tournament flagged as **off-platform-prize** must satisfy one of:

1. **Free entry** — platform just runs the bracket; no stake at all. (Safest, default.)
2. **Ticket entry (swap)** — entry is paid in a **non-purchasable "Entry Ticket"** earned only through
   play, never bought. Money can't enter the stake path.
3. **Annulled entry (burn)** — if coins/gems are spent to enter, they are **burned to the sink**, not
   pooled and not redistributed. They function as an *access/listing cost*, not a stake. The platform
   holds **no pool**, takes **no rake**, and is **not a party** to the off-platform prize.

Why burn rather than pool: if we pooled *purchasable* gems and the host also paid cash, those gems
would effectively be a cash-convertible buy-in. Burning (or swapping to a non-redeemable ticket)
severs that link → stays non-gambling. This is the "our coins should be swapped or annulled" rule.

Guardrails for off-platform-prize tournaments:
- Restricted to **verified Max organizers**; explicit ToS disclaimer that the platform is not a party
  to any off-platform prize and provides tooling only.
- Enforced in `settings` jsonb (e.g. `settlement: 'off_platform'` forces entry mode to free/ticket/burn
  and disables `prize_pool` payout + rake).
- No on-platform `tournament_prize` credits are emitted for these.

### 3.3 On-platform settlement modes (the default, fully virtual)
**DECISION (locked): support both funding models.**

**A — Platform-funded (official events).** Fixed pool minted by the platform; entry free or a small
coin sink. A marketing/engagement cost. Keep these **coin- and cosmetic-heavy with only small gem
prizes** — minting hard currency dilutes the gem economy.

**B — Player-funded pool + rake (competitive events).** Entry × participants = gross pool; **platform
takes a rake (~10% default, configurable per tournament); winners split the remainder.** Poker/Clash
economics. Rake on *gem* tournaments is a hard-currency **sink** — the healthiest sink available.
**The host never extracts the pool — the rake goes to the platform**, which removes the
collusion/farming incentive.

### 3.4 Suggested entry & payout ladder

| Class | Entry | Rake | Payout shape |
|---|---|---|---|
| Freeroll (acquisition) | Free | — | Platform-funded, top ~15% |
| Casual coin | 100–500 coins | 10% | Top-heavy 50/30/20 |
| Competitive gem | 25 / 50 / 100 gems | 10–15% | Top ~10–15% of field |
| Pro/Max exclusive | gems | lower/0 rake (perk) | Top-heavy |

Payout curves (poker/esports norms): winner-take-all for ≤8; 50/30/20 for ~16; pay top 10–15% for
large fields. Also offer a **Clash-Royale-style "win ladder"** (reward by *number of wins*, not final
rank) for arena-format events — feels generous, reduces "lost round 1, got nothing" churn.

### 3.5 Escrow & ledger (virtual)
No separate escrow account needed for virtual currency:
- **Register:** debit entry → `currency_transactions` (reason `tournament_entry`, `reference_id =
  tournament_id`). Must be **server-authoritative** (edge function), not the current client-side
  `register()` which writes the participant row directly.
- **Unregister / cancellation (min_participants not met):** credit back (reason `tournament_refund`).
- **Completion:** pay out from implicit pool (reason `tournament_prize`).
- Invariant: `sum(payouts) ≤ gross × (1 − rake)`; `gross = sum(entry debits)`.

---

## 4. Tracking participants & wins

Schema is strong; **server logic is what's missing.**

`tournament_participants` already carries `wins/losses/draws/points/game_wins/buchholz/seed/status`.
`tournament_matches` already carries full bracket-advance wiring (`next_match_id`, `next_match_slot`,
`loser_next_match_id`, `room_id`). Needed:

1. **`tournament-register` edge fn** — server-side fee debit, create participant, increment count,
   enforce tier/capacity/concurrency limits.
2. **Bracket generation on start** — seed (by rating or random), populate matches. Make the existing
   `bracket_generator.dart` logic authoritative server-side.
3. **Match → room** — when a match is `ready`, create a `game_rooms` row with `social_mode = focus`,
   link `tournament_matches.room_id`. (Room lifecycle is game-agnostic — clean seam.)
4. **Result ingestion** — on room `finished`, read winner, set `match.winner_id`, advance to
   `next_match_id/slot`, update participant W/L. **Tournament matches forfeit on disconnect after
   grace** (integrity) rather than silently bot-substituting (the default room behavior).
5. **Completion** — compute `final_standings`, pay out pool, set `winner_id`.
6. **Refund** — cancel + credit entries back if `min_participants` not met.

**Lifetime win tracking** ("keep track of their wins"): add aggregates —
`tournaments_played`, `tournaments_won`, `total_winnings`, best finish — as a view over
`tournament_participants` or columns on `profiles`. Feeds profile badges + a tournament leaderboard
(the prestige/retention layer competitors lean on).

---

## 5. Free vs. paid — summary of differentiation

| Capability | Free | Pro | Max |
|---|---|---|---|
| Join official/community tournaments | ✅ | ✅ | ✅ |
| Concurrent tournament registrations | limited (e.g. 1) | more | most |
| Sees ads in tournament UI | ✅ | ❌ | ❌ |
| Join Pro/Max-exclusive tournaments (`min_subscription_tier`) | ❌ | ✅ (Pro) | ✅ |
| **Host community tournaments** | ❌ | ✅ ≤16 | ✅ large/custom/recurring |
| Gem prize pools when hosting | — | capped | full |
| Off-platform-prize hosting (verified) | — | — | ✅ |

Hosting + exclusive access is the subscription value; *competing* stays accessible to everyone (good
for retention and fairness). Tournaments grant **generous XP** (participation + placement) into global
and season tracks — connecting them to the season-pass loop.

---

## 6. Anti-abuse notes
- Rake makes gem-tournament farming net-negative; host-can't-extract-pool removes collusion incentive.
- Min participants + check-in window; no-show → bye/forfeit + refund policy.
- Seed by rating to limit smurf advantage.
- Disconnect → grace + rejoin, else **forfeit the match** (do not bot-sub in competitive play).
- Off-platform-prize events: verified organizers only, burn/ticket entry, ToS disclaimer.

---

## 7. Build order (phased — none built yet)

- **Phase 0 — Game-end reward loop** *(prerequisite; unblocks the whole economy)*: call
  `record_game_completion`, grant coins/XP/season-XP at game end, wire `game_over_dialog`.
- **Phase 1 — Official tournament MVP**: `tournament-register` (server fee debit) → bracket gen →
  match→room → result ingestion → payout; finish `tournament_detail_screen` (registration/bracket/chat
  repos already exist).
- **Phase 2 — Economy surfacing**: implement stubbed Flutter currency/season/challenge repos; rake +
  escrow ledger discipline; tournament lifetime stats + leaderboard.
- **Phase 3 — Community hosting + subscription gating**: Pro/Max host rights, gem pools, exclusive
  tournaments, off-platform-prize mode (burn/ticket settlement), anti-abuse.
- **Phase 4 — Advanced**: Swiss/round-robin/double-elim/arena formats, recurring events, late
  registration, re-buys.

---

## 9. Economy workflows — earn, redeem, and money flow

All numbers below are either **already in the codebase** (marked ✅) or **proposed** (marked ⊕, not yet
built). Coins = soft/abundant; Gems = hard/scarce (mostly bought).

### 9.1 Currency earn matrix (faucets) — who earns what

| Faucet | Coins | Gems | XP | Free | Pro | Max | Status |
|---|---|---|---|:--:|:--:|:--:|---|
| Game end — win | ~40 ⊕ | — | ✅ yes | ✅ | ✅ | ✅ | ⊕ Phase 0 |
| Game end — loss (participation) | ~12 ⊕ | — | yes | ✅ | ✅ | ✅ | ⊕ Phase 0 |
| First win of the day | +100 ⊕ | — | bonus | ✅ | ✅ | ✅ | ⊕ Phase 0 |
| Daily login streak | 15→100 ✅ | day7+: 10→50 ✅ | day7: 300 ✅ | ✅ | ✅ | ✅ | ✅ wired |
| Daily challenges (3) + weekly (5) | per challenge ✅ | rare ✅ | per challenge ✅ | ✅ | ✅ | ✅ | ✅ wired |
| Season pass — free track | per level ✅ | small ✅ | — | ✅ | ✅ | ✅ | ✅ wired |
| Season pass — premium track | per level ✅ | larger ✅ | — | buy 500💎 | buy 500💎 | **included** | ✅ wired |
| Referral (tier 1 / tier 4) | 100 / — ✅ | — / 50 ✅ | — | ✅ | ✅ | ✅ | ✅ partial |
| Rewarded ad (watch to earn) | ~25/ad ⊕ | — | — | ✅ | ❌ (no ads) | ❌ | ⊕ stub exists |
| Monthly subscription grant | — | — | — | ❌ | 800c+80💎 ✅ | 2500c+300💎 ✅ | ✅ wired |
| Tournament prize | pool share | pool share | placement ⊕ | ✅ | ✅ | ✅ | ⊕ Phase 1 |
| **Tier earn multiplier** (on game-end + coin winnings) | ×1.0 | ×1.25 ⊕ | ×1.5 ⊕ | — | ⊕ | ⊕ | ⊕ proposed |

Key principle: **gems are almost never earned from raw gameplay** — they come from buying, the season
pass, rare challenges, and subscription grants. That scarcity is what gives them value as the premium
sink currency. Coins flow freely from playing.

### 9.2 Workflow A — How a FREE user earns

```
              ┌─────────────── daily ───────────────┐
  open app → claim daily streak (15–100 coins, gems only day 7+)
       │
       ▼
  play a game ──win──► +40 coins +XP   (first win of day: +100)
       │        └─loss─► +12 coins +XP
       ▼
  watch a rewarded ad (optional) ──► +~25 coins      ← Free-only lever
       │
       ▼
  XP fills global level + active SEASON level
       │
       ▼
  complete daily/weekly challenges ──► claim ──► coins + occasional gems + XP
       │
       ▼
  invite a friend (referral tier 1) ──► +100 coins
```
Net: a free user is **coin-rich, gem-poor**. They accumulate gems slowly (daily streak + rare
challenges + free season track) — enough to *occasionally* enter a gem tournament or save toward the
premium pass, which is the nudge toward subscribing. Watching ads is their unique extra-coin lever.

### 9.3 Workflow B — How a PRO / MAX user earns

```
  subscribe ──► immediate + monthly grant:  Pro 800 coins + 80 gems
       │                                     Max 2500 coins + 300 gems
       ▼
  no ads (cleaner UX) — gives up the rewarded-ad coin lever,
       │                compensated by the grant + earn multiplier
       ▼
  play a game ──win──► +40 ×(1.25 Pro / 1.5 Max) coins  ⊕  +XP
       │
       ▼
  same daily / challenge / season / referral faucets as Free
       │
       ▼
  MAX only: premium season pass INCLUDED (saves 500 gems/season)
       │
       ▼
  Pro/Max: can HOST tournaments → drive their own community
           can JOIN tier-exclusive tournaments (bigger pools)
```
Net: paid users get a **steady gem inflow** (grant) they'd otherwise have to buy, an **earn
multiplier** on coins, the premium pass value, and the **hosting + exclusive-access** privileges.
The pitch is "earn faster, skip ads, host your own, unlock exclusive competition."

### 9.4 Workflow C — What currency is redeemed for (sinks)

```
COINS (soft) spent on:                      GEMS (hard) spent on:
  • cosmetics priced in coins                 • premium cosmetics (50–75💎)
    (e.g. Modern deck 500 ✅)                  • season pass premium (500💎 ✅)
  • challenge reroll (25 coins ✅)             • competitive tournament entry (25–100💎)
  • casual tournament entry (100–500)         • tier-exclusive tournament entry
  • [optional ⊕ gem→coins one-way]            • [optional ⊕ gem→coins exchange]
```
**No coin→gem conversion** (protects gem value / revenue). A one-way **gem→coin** exchange is
optionally fine (hard→soft is a healthy sink) but not required. There is **no cash-out** — virtual
currency is never redeemed for money on-platform (§3).

### 9.5 Workflow D — Tournament money flow (player-funded, the rake model)

```
  16 players × 50💎 entry ─────────────► GROSS POOL = 800💎
       │  (each: debit 50💎, reason 'tournament_entry', ref=tournament_id)
       ▼
  platform RAKE 10% = 80💎 ──────────────► platform (gem SINK, removed from economy)
       │
       ▼
  NET POOL = 720💎  split 50/30/20:
       1st ► 360💎   2nd ► 216💎   3rd ► 144💎
       │  (credit, reason 'tournament_prize', ref=tournament_id)
       ▼
  cancelled (min_participants not met) ──► refund every entry (reason 'tournament_refund')
```
Invariant enforced server-side: `sum(payouts) = gross × (1 − rake)`. Host receives **nothing** from
the pool (rake → platform), which kills collusion incentive.

### 9.6 Workflow E — Tournament money flow (platform-funded official event)

```
  entry: FREE (or small coin sink, e.g. 100 coins)
       │
       ▼
  prize pool MINTED by platform (engagement cost), coin/cosmetic-heavy:
       1st ► 500 coins + 20💎 + exclusive skin
       2nd ► 300 coins
       3rd ► 150 coins
       top 15% ► consolation coins
```
Gems minted here are kept **small** to avoid diluting the hard-currency economy.

### 9.7 Workflow F — Off-platform real-money tournament (host-funded, verified Max only)

```
  host advertises a real cash prize they fund + settle OFF-PLATFORM
       │
       ▼
  on-platform entry MUST be one of:
       • free  (platform just runs the bracket)              ← default
       • non-purchasable Entry Ticket (earned, never bought) ← "swap"
       • coins/gems BURNED to sink, not pooled               ← "annul"
       │
       ▼
  platform: NO pool held, NO rake, NOT a party to the prize (ToS disclaimer)
```
This severs "purchasable currency → cash prize," keeping the platform a game, not a betting operator.

### 9.8 The core loop (why it all connects)

```
   play games ─► earn coins + XP ─► XP fills season/level ─► claim reward (coins/gems)
        ▲                                                              │
        │                                                              ▼
   retention ◄─ prestige/badges ◄─ win tournaments ◄─ spend coins/gems on entry & cosmetics
        ▲                                                              │
        └──────────── subscribe (boosts, no ads, host, exclusive) ◄────┘
                                   │
                          buy gems with money  ───►  REVENUE
```
Gems are the bridge to revenue: scarce in-game, bought with money, sunk into the season pass,
premium cosmetics, and the rake.

---

## 10. Coins → gems: the skill bridge (configurable faucet)

**Principle: coins never *convert* to gems. Coins buy *entry* to competitions whose top prizes are
seeded in gems by the platform.** Coins are the buy-in; gems are the trophy for placing. The median
entrant loses their coins (sink); gems flow only to skill/persistence — never a flat exchange rate.

### 10.1 Mechanism A — "Gem Cups" (coin entry, gem prizes) — primary
Coin-entry tournament: the coin pool pays most places as normal (self-funded + rake), and the platform
seeds a **small gem bonus on the top 1–3 only**.
```
32 × 500 coins = 16,000 coin GROSS → 10% rake → coin prizes to top ~15% (self-funded)
   + platform-seeded gem bonus, top 3 ONLY:  1st +100💎  2nd +50💎  3rd +25💎
```
Entering and losing yields zero gems. Only podiuming does. Gem seeding is a controlled faucet.

### 10.2 Mechanism B — Ranked seasonal gem payout — persistence
Coin/free tournament results feed a **Rating/MMR**; at season end, rank tiers pay gems
(Bronze 0 / Silver 20 / Gold 50 / Diamond 150 / Master 300 💎). Rewards volume + skill; paid once per
season so it can't be farmed.

### 10.3 Guardrails (why the faucet stays safe)
- Top finishers only (never participation); skill is the gate.
- Per-tournament gem budget + capped Gem-Cup frequency; ranked payout once/season.
- **Per-account weekly gem-from-tournament cap** + bot/smurf detection.
- Keep amounts modest so impatient players still *buy* gems (protect revenue) — Clash Royale model:
  premium currency is earnable free but slowly.

### 10.4 Configurable — everything lives in `economy_config` (server-driven, Remote-Config style)
**DECISION (locked): the gem faucet is configurable, not hardcoded.** A single server-side config
surface (DB table / JSONB) tunes the whole economy without an app release. Knobs:
- `game_end_coins_win` / `_loss`, `first_win_of_day_bonus`
- `tier_earn_multiplier` { free, pro, max }
- `gem_cup_enabled`, `gem_cup_daily_limit`, `gem_cup_min_players`, `gem_cup_prize_split` {1,2,3}
- `ranked_gem_payout` { tier → gems }
- `weekly_gem_from_tournament_cap_per_user`
- `rake_percent_default`

"Conservative vs generous" (how fast free players reach premium gems) becomes a dial.

---

## 11. Gem privileges — what gems are for

Gems = premium-access + prestige + competitive-stakes + creation currency. Every use is also a revenue
lever (gems are scarce + mostly bought).

| Privilege | Detail | Status |
|---|---|---|
| Premium season pass | Unlock premium reward track (500💎); Max gets it free | ✅ |
| Premium cosmetics | Gem-only decks/backgrounds/frames/emotes (Neon 50💎, Casino bg 75💎) — status | ✅ seeded |
| Competitive tournament entry | Bigger-stakes gem tournaments, larger pools | ⊕ |
| Tier-exclusive tournaments | Higher-prize events gated by `min_subscription_tier` | ⊕ |
| Hosting gem-pool tournaments | Pro/Max fund gem prize pools for their community | ⊕ |
| Prestige / vanity | Limited gem-only items, profile flair | ⊕ |

Coins keep you *playing*; gems let you *flex, compete at stakes, and create*.

---

## 12. XP — the progression meter (how XP helps)

XP is a **meter, never a currency** — earned, never spent. There are **four distinct meters**; keeping
them separate is essential:

| Meter | Earn by | Spend? | Purpose |
|---|---|---|---|
| Coins | playing | yes | soft currency — entries, cosmetics |
| Gems | buying / winning / pass | yes | hard currency — premium access |
| **XP / Level** | playing, challenges, daily | **no** | progression + unlocks + status |
| **Rating / MMR** | competitive results | no | matchmaking + tournament seeding + ranked gem payout |

XP helps in three ways:
1. **Season XP → battle pass.** Every game's XP fills the season level; each level pays coins/gems/skins
   (free track + bigger premium track). This makes the **season pass itself a gem faucet for everyone** —
   another non-conversion path for active free players to slowly earn gems. XP is what makes the pass tick.
2. **Global level → prestige + unlocks + faucet.** Permanent identity/badge; gates features (referral
   tier 3 = "reach level 5", already in schema; can gate ranked eligibility, titles); **each level-up can
   grant a coin/gem reward** ⊕ — a drip rewarding long-term engagement.
3. **Skill stays separate from grind.** Seeding + ranked gem payouts use **Rating/MMR, not XP** — a
   high-level grinder gets no unfair bracket, a skilled newcomer isn't buried. XP rewards *showing up*;
   rating rewards *winning*.

---

## 8. Locked decisions (2026-06-30)
1. **Scope now:** design only; no implementation yet.
2. **Money:** virtual-only on-platform; off-platform real-money prizes allowed only with currency
   **swapped to non-purchasable ticket or annulled/burned** — platform never converts money → prize.
3. **Hosting:** community tournaments are **Pro/Max only**; Free joins only.
4. **Prize funding:** **both** platform-funded official events and player-funded events with a ~10%
   configurable rake.
