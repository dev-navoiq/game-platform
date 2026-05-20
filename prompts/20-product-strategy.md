# 20 — Product Strategy & Monetization Blueprint

> **Purpose**: Comprehensive product strategy covering gap analysis, refined subscription tiers, coin/gem economy, friends-activity UX, global payments, and ad-placement design. Complements and upgrades prompts 12–14.

---

## Part 1 — Gap Analysis (What's Missing)

After reviewing all 19 existing prompts, the following areas are under-defined or absent:

### 1.1 Missing Screens & Flows

| Gap | Impact | Recommendation |
|-----|--------|----------------|
| **Onboarding / First-Time UX** | New players hit the home screen cold; no tutorial, no guided first game | Add a 3-step onboarding wizard: pick favourite game → play a quick bot match → claim welcome bonus |
| **Friends Activity Feed** | `12-social-features.md` has a friends repo but no **live feed** showing what friends are playing | Add a real-time "Friends Playing" strip on home + a dedicated Friends tab |
| **Quick-Join / Spectate** | No way to jump into a friend's ongoing game as spectator or join their next round | Add "Join" and "Watch" deep-link buttons on friend activity cards |
| **Battle Pass / Season Pass** | Missing entirely; industry standard for retention | Design a 30-day Season Pass with free + premium tracks |
| **Daily / Weekly Challenges** | Only daily login bonus exists; no mission system | Add 3 daily + 5 weekly challenges that reward coins/XP |
| **XP & Level System** | No player progression beyond raw game stats | Add an XP bar and level system; levels unlock cosmetic rewards |
| **Referral System** | No viral loop mechanism | Add invite codes that give both referrer and invitee coins + a unique skin |
| **Push Notification Strategy** | Only mentioned in `notifications_enabled` boolean | Define notification categories: friend activity, turn reminders, tournament alerts, daily bonus unclaimed |
| **Accessibility** | Only "semantic labels, sufficient contrast" mentioned in quality standards | Need full a11y spec: screen reader, reduced motion, colour-blind modes, scalable text |
| **Offline Mode** | Not addressed | Allow vs-bot play offline with state sync on reconnect |
| **Localisation / L10N** | "No hardcoded strings" is mentioned but no language list or RTL plan | Prioritise: English, Hindi, Portuguese, Arabic (RTL), Spanish, Bahasa, Thai |
| **Age-Gate / Parental Controls** | Absent | Required for app store compliance; add COPPA-safe mode |
| **Anti-Addiction Measures** | Absent | Required in India and China; add session-time reminders after 60 min |
| **Silent / Chat-Free Rooms** | No option to disable social features per room | Add room-level social mode: Full (chat + voice + emotes), Chat Only (text + emotes, no voice), Silent (emotes only), Focus (zero distractions) |
| **Floating Chat Bubbles** | Chat is relegated to a side tab; easy to miss | Add floating speech bubbles above player avatars for recent messages — auto-dismiss after 4 sec |

### 1.2 Under-Defined Systems

| Area | Current State | Upgrade Needed |
|------|---------------|----------------|
| **Coin Economy** | Basic earn/spend with flat numbers | Full sink/source balance with inflation control (see Part 3) |
| **Matchmaking** | Edge function stub; no skill-rating detail | Add Glicko-2 or TrueSkill rating; rating floors per game |
| **Spectator Mode** | Not mentioned | 30-sec delayed spectator stream for anti-cheat; "Watch" button |
| **Game Replay** | `17-favorites-and-history.md` mentions replay but no viewer spec | Define replay playback UI with speed controls, move-by-move navigation |
| **Clan / Club System** | Absent | Post-launch feature: clubs with shared leaderboard, club tournaments |
| **Customer Support / In-App Help** | Absent | Add FAQ + in-app ticket system (Zendesk widget or custom) |

---

## Part 2 — Subscription Tiers (Refined)

### 2.1 Tier Matrix

| Feature | Free | Pro | Max |
|---------|------|-----|-----|
| **Monthly price (US)** | $0 | **$3.99/mo** | **$7.99/mo** |
| **Annual price (US)** | $0 | $38.99/yr (save 19%) | $74.99/yr (save 22%) |
| **All games playable** | Yes | Yes | Yes |
| **Ads** | Banner + interstitial (game-end) | **Rewarded only** (opt-in) | **Zero ads** |
| **Voice chat** | 2 min/game (teaser) | Unlimited | Unlimited |
| **Card skins** | 2 (Classic + 1 earned) | 6 exclusive | All current + future |
| **Room skins** | 1 (Classic) | 3 exclusive | All current + future |
| **Emotes** | 5 basic | 15 (incl. animated) | 30+ (all, incl. animated) |
| **Monthly coins** | 200 | 800 | 2 500 |
| **Monthly gems** | 0 | 80 | 300 |
| **Private rooms** | 1/day | Unlimited | Unlimited |
| **Room capacity** | Up to 4 | Up to 6 | Up to 8 |
| **Custom room rules** | No | Yes | Yes |
| **Priority matchmaking** | No | Yes | Yes |
| **Statistics** | Basic (W/L) | Detailed (per-game analytics) | Full analytics + exportable CSV |
| **Leaderboard flair** | None | Silver frame | Gold animated frame |
| **Profile badge** | None | "Pro" badge | "Max" badge + animated glow |
| **Season Pass premium track** | No | Yes | Yes + bonus season XP (20%) |
| **Tournament entry discount** | None | 10% off gem entry fees | 25% off gem entry fees |
| **Friend list cap** | 50 | 200 | Unlimited |
| **Spectator slots per room** | 2 | 5 | 10 |

### 2.2 Pricing Changes vs. Original

- **Pro dropped from $4.99 → $3.99**: Aligns with mobile-gaming sweet spot; Chess.com Gold is ~$5 but includes deep analysis tools we don't offer yet. $3.99 is the impulse-buy threshold.
- **Max dropped from $9.99 → $7.99**: Keeps it under the "two-coffee" mental benchmark; still 2× Pro.
- **Free tier improved**: Bumped monthly coins 100 → 200 and added 2-min voice teaser so free users *experience* the premium feature and want more.
- **Removed "gems for free"** misconception: Free users earn coins only; gems remain a premium signal.

### 2.3 Country-Specific Pricing

RevenueCat + App Store / Play Store handle local pricing tiers. Below are our recommended **price-point anchors** (approximate local equivalents):

| Region | Pro (monthly) | Max (monthly) | Pro (annual) | Max (annual) |
|--------|---------------|---------------|--------------|--------------|
| **US / Canada** | $3.99 | $7.99 | $38.99 | $74.99 |
| **EU / UK** | €3.99 / £3.49 | €7.99 / £6.99 | €37.99 / £34.99 | €72.99 / £67.99 |
| **India** | ₹149 (~$1.75) | ₹299 (~$3.50) | ₹1 399 | ₹2 799 |
| **Brazil** | R$12.90 | R$24.90 | R$119.90 | R$229.90 |
| **SE Asia (ID/PH/TH)** | $1.49 equiv. | $2.99 equiv. | $13.99 | $27.99 |
| **Middle East (AE/SA)** | AED 14.99 | AED 29.99 | AED 139.99 | AED 279.99 |

**Principle**: India and SE Asia at ~40-50% of US price; Brazil ~55%; Middle East at parity or slight premium. These match Apple's recommended price tiers for each storefront.

---

## Part 3 — Coin & Gem Economy

### 3.1 Dual-Currency Philosophy

| | Coins (Soft) | Gems (Hard) |
|---|---|---|
| **How earned** | Gameplay, challenges, ads, daily bonus | Subscription, IAP, rare achievements |
| **Primary use** | Tournament entry, basic cosmetics, room creation | Premium cosmetics, Season Pass, exclusive skins |
| **Can be purchased?** | No (earned only) | Yes (IAP + subscription grant) |
| **Psychological role** | Activity reward; keep players playing | Scarcity signal; drive subscriptions & IAP |

### 3.2 Coin Sources (Daily Budget for Free Player)

| Source | Coins/Day | Notes |
|--------|-----------|-------|
| Daily login | 15–60 | Scales with consecutive days (see below) |
| Win a game | 20 | 10 for 2nd place; 5 for loss (participation) |
| Complete daily challenge (×3) | 25 each = 75 | e.g., "Win 2 Hearts games", "Play 5 rounds" |
| Weekly challenge bonus (÷7) | ~30 | 200 coins for completing 5/5 weeklies |
| Watch rewarded ad (×3 max) | 30 each = 90 | Cooldown: 1 per 20 min |
| **Realistic daily total** | **~200–280** | Assumes moderate play (4-5 games + 2 ads) |

### 3.3 Daily Login Streak

| Day | Coins | Gems | Special |
|-----|-------|------|---------|
| 1 | 15 | — | — |
| 2 | 20 | — | — |
| 3 | 25 | — | — |
| 4 | 30 | — | — |
| 5 | 40 | — | — |
| 6 | 50 | — | — |
| 7 | 60 | 10 | Random emote OR card skin preview |
| 14 | 80 | 20 | Exclusive 14-day streak avatar frame |
| 30 | 100 | 50 | Exclusive "Dedicated" profile badge |

After day 30 the streak cycles back to day-1 rewards but the badge persists.

### 3.4 Coin Sinks (Where Players Spend)

| Sink | Cost | Purpose |
|------|------|---------|
| Enter casual tournament | 50–200 coins | Volume drain; keeps economy moving |
| Enter ranked tournament | 100–500 coins | Higher stakes, better rewards |
| Buy basic emote | 500 coins | Cosmetic; low urgency |
| Buy basic card skin | 2 000 coins | ~7-10 days of play; aspirational |
| Buy basic room skin | 3 000 coins | ~12-15 days; longer goal |
| Room creation (custom rules) | 25 coins | Micro-sink on every room |
| Re-roll daily challenge | 30 coins | Convenience spend |
| Undo last move (casual only) | 50 coins | Fun convenience; card games only in casual |
| Gift emote to friend | 150 coins | Social spend |

### 3.5 Gem Sinks

| Sink | Cost | Purpose |
|------|------|---------|
| Season Pass (premium track) | 500 gems | ~$5 equivalent; 30-day content |
| Premium card skin | 200–400 gems | Animated / limited-edition |
| Premium room theme | 300–600 gems | High-fidelity environments |
| Animated avatar frame | 150 gems | Profile flair |
| Tournament fast-pass (skip queue) | 50 gems | Convenience |
| Name-change token | 100 gems | Rare use; revenue neutral |

### 3.6 Gem IAP Packs

| Pack | Gems | Price (US) | Bonus | $/Gem |
|------|------|------------|-------|-------|
| Starter | 100 | $0.99 | — | $0.0099 |
| Popular | 550 | $4.99 | +10% | $0.0091 |
| Best Value | 1 200 | $9.99 | +20% | $0.0083 |
| Mega | 2 600 | $19.99 | +30% | $0.0077 |
| Whale | 7 000 | $49.99 | +40% | $0.0071 |

### 3.7 Economy Health Rules

1. **Inflation cap**: If average free-player coin balance exceeds 5 000, add a limited-time cosmetic sink (flash sale).
2. **Floor**: Never let a free player feel "stuck" — participation coins (5/game) ensure nobody hits zero.
3. **No pay-to-win**: Coins/gems never buy gameplay advantage (no extra cards, no better bots, no score multipliers).
4. **Seasonal reset**: Tournament leaderboards reset each season; coin balances persist.
5. **Audit table**: Every transaction logged in `currency_transactions` with reason, reference_id, and balance snapshots.

---

## Part 4 — Friends Activity & Quick-Join

### 4.1 Friends Activity Strip (Home Screen)

A horizontal scrollable strip at the top of the home screen showing real-time friend status:

```
┌──────────────────────────────────────────────────┐
│  FRIENDS PLAYING                           See All│
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐│
│ │ 🟢 Raj  │ │ 🟢 Sara │ │ 🟡 Mike │ │ + Invite ││
│ │ Oh Hell │ │ Chess   │ │ Lobby   │ │  Friends ││
│ │ Round 3 │ │ Move 12 │ │ Waiting │ │          ││
│ │ [Watch] │ │ [Watch] │ │ [Join]  │ │          ││
│ └─────────┘ └─────────┘ └─────────┘ └──────────┘│
└──────────────────────────────────────────────────┘
```

**States**:
- 🟢 **In Game** — shows game name, round/move — button: "Watch" (spectator)
- 🟡 **In Lobby** — shows game name + "Waiting" — button: "Join" (if seats available)
- 🔵 **Online** (idle) — shows "Online" — button: "Invite" (opens game-picker)
- ⚫ **Offline** — dimmed, shows "Last seen 2h ago" — no action button

### 4.2 Database Additions

```sql
-- Real-time presence (extends existing profiles)
-- Uses Supabase Presence (Realtime) not a table, but we store last state:

ALTER TABLE profiles ADD COLUMN current_activity JSONB DEFAULT NULL;
-- Example: {"type": "in_game", "game_type": "oh_hell", "room_id": "...", "room_code": "ABCD", "round": 3, "spectatable": true, "joinable": false}
-- NULL = offline

CREATE INDEX idx_profiles_activity ON profiles USING GIN (current_activity) WHERE current_activity IS NOT NULL;
```

### 4.3 Quick-Join Flow

1. Player sees friend card with "Join" button.
2. Tap "Join" → app calls `POST /join-room` edge function with `room_id`.
3. Edge function checks: room not full, player not banned, game not started.
4. If **game already started**: show "This game is in progress. Watch instead?" with "Watch" and "Notify me when next game starts" buttons.
5. If **room full**: show "Room is full (4/4). Want me to notify you when a seat opens?" — subscribes to room presence.
6. If **joinable**: player slides into the room seamlessly; existing players see a toast "[Name] joined!".

### 4.4 Spectator Mode

- 30-second delay to prevent cheating (card games); no delay for chess.
- Spectators see all cards face-down except the active trick.
- Spectator chat is separate from player chat (spectators can only see each other).
- Free: 2 spectator slots per room. Pro: 5. Max: 10.

### 4.5 Invite Flow

```
Player taps "Invite" on a friend card
  → Game picker modal: "Invite [Name] to play..."
    → Grid of game icons (Oh Hell, Chess, Ludo...)
    → Tap a game → creates private room → sends push + in-app notification
    → Friend receives: "[You] invited you to play Oh Hell! [Accept] [Decline]"
    → Accept → friend joins room → game starts when ready
```

Deep links: `gameplatform://room/ABCD` works for both in-app navigation and external sharing (SMS, WhatsApp).

---

## Part 5 — Global Payment Strategy

### 5.1 Architecture

```
┌──────────────────────────────────────────────┐
│              RevenueCat (Orchestrator)         │
│  ┌──────────┐  ┌──────────┐  ┌─────────────┐│
│  │ Apple IAP│  │Google Play│  │ Stripe (Web)││
│  │   (iOS)  │  │ Billing   │  │             ││
│  └──────────┘  └──────────┘  └─────────────┘│
│                                              │
│  Server-side webhook → Supabase Edge Function│
│  → Update profiles.subscription_tier         │
│  → Grant monthly coins/gems                  │
│  → Log to currency_transactions              │
└──────────────────────────────────────────────┘
```

### 5.2 Platform-Specific Strategy

| Platform | Payment Provider | Notes |
|----------|------------------|-------|
| **iOS** | Apple IAP (mandatory) | 30% commission (15% for <$1M/yr via Small Business Program) |
| **Android** | Google Play Billing (mandatory for Play Store) | 15% on first $1M/yr, then 30% |
| **Web** | Stripe | 2.9% + $0.30; major cost advantage — push web subscriptions |
| **Web (India)** | Stripe + Razorpay fallback | UPI Autopay for recurring; Razorpay has better UPI coverage |
| **Web (Brazil)** | Stripe + local acquirer | Pix instant payment for one-time gem packs; boleto for bank transfer |
| **Web (SE Asia)** | Stripe + local wallets | GrabPay (SG/MY/PH), GoPay (ID), TrueMoney (TH) via Stripe Connect |

### 5.3 Cross-Platform Subscription Sync

RevenueCat handles this natively:
1. User subscribes on iOS → RevenueCat stores entitlement.
2. User logs into Android → RevenueCat API returns active entitlement → app grants Pro/Max.
3. Webhook fires on renewal/cancellation → Edge Function updates `profiles.subscription_tier`.

**Price anchoring trick**: Show web price ($3.99) next to "App Store price ($4.49)" to drive web subscriptions and avoid 30% commission. Apple allows this as of 2024 ruling (external link allowed if user initiates).

### 5.4 Regional Payment Method Matrix

| Region | Subscriptions | One-Time (Gems) | Carrier Billing |
|--------|---------------|------------------|-----------------|
| **US/CA** | Apple/Google/Stripe | Apple/Google/Stripe | N/A |
| **EU/UK** | Apple/Google/Stripe | Apple/Google/Stripe (SEPA, iDEAL via Stripe) | N/A |
| **India** | Google Play / Stripe+UPI Autopay | Google Play / UPI / Razorpay | Jio, Airtel (phase 2) |
| **Brazil** | Google Play / Stripe+Pix | Google Play / Pix / Boleto | Claro, Vivo (phase 2) |
| **SE Asia** | Google Play / Stripe+wallets | GoPay, GCash, TrueMoney | Telkomsel, Globe (phase 2) |
| **Middle East** | Apple/Google | Apple/Google / local cards | Etisalat (phase 2) |

### 5.5 Fraud Prevention

- RevenueCat flags subscription fraud (family sharing abuse, refund abuse).
- Edge function validates gem-pack purchases server-side before crediting.
- Rate-limit gem grants: max 5 purchases per 24 hours.
- IP-based anomaly detection for web payments (Stripe Radar).

---

## Part 6 — Season Pass System (New Feature)

### 6.1 Structure

A 30-day pass with **two tracks** (similar to battle passes in mobile games):

| Level | Free Track | Premium Track (500 gems) |
|-------|-----------|--------------------------|
| 1 | 50 coins | Animated card back "Nebula" |
| 3 | Emote: "GG" | 100 coins |
| 5 | 100 coins | Avatar frame "Season 1" |
| 7 | Emote: "Nice!" | 200 gems |
| 10 | 200 coins | Exclusive card skin "Holographic" |
| 13 | 50 coins | 150 coins |
| 15 | 150 coins | Room theme "Midnight Casino" |
| 18 | Emote: "Wow" | 300 gems |
| 20 | 300 coins | Animated avatar "Champion's Glow" |
| 25 | 200 coins | 500 coins |
| 30 | 500 coins + "Season Veteran" badge | Legendary card skin "Aurora" + Title: "Season 1 Legend" |

**XP earning**: Every game played = 100 XP. Win bonus = +50 XP. Daily challenge = 200 XP each. Weekly challenge = 500 XP each. Level-up = 1 000 XP per level.

### 6.2 Pro/Max Bonus

- **Pro subscribers**: Premium track included free.
- **Max subscribers**: Premium track included + 20% bonus XP.

---

## Part 7 — Daily & Weekly Challenges

### 7.1 Daily Challenges (3 per day, refresh at midnight UTC)

Examples:
- "Win 2 games of any type" — 25 coins
- "Play 3 rounds of Oh Hell" — 30 coins
- "Use a voice chat session" — 20 coins + voice teaser (free users)
- "Send 5 emotes during games" — 15 coins
- "Win a game without losing a single trick" — 50 coins (hard)

### 7.2 Weekly Challenges (5 per week)

Examples:
- "Play all 3 card games at least once" — 100 coins
- "Win 10 games total" — 150 coins
- "Invite a friend and play together" — 200 coins + 10 gems
- "Reach a 7-day login streak" — 100 coins
- "Finish top 3 in a tournament" — 300 coins + 20 gems

### 7.3 Re-Roll

Players can re-roll one daily challenge per day for 30 coins. Pro/Max users get 1 free re-roll.

---

## Part 8 — Ad Placement Strategy (Detailed)

### 8.1 Placement Map

| Placement | Type | Free Users | Pro Users | Max Users | Frequency |
|-----------|------|-----------|-----------|-----------|-----------|
| **Lobby Banner** | Banner (320×50) | Yes | No | No | Always visible in lobby |
| **Game-End Card** | Native Ad (in results screen) | Yes | No | No | After every game |
| **Rewarded Video** | Fullscreen (15-30s) | Yes | Yes (opt-in) | Yes (opt-in) | Max 5/day, 20-min cooldown |
| **Room List Native** | Native card among rooms | Yes | No | No | Every 5th room card |
| **Interstitial** | Fullscreen on back-to-lobby | Yes | No | No | Max 2/session, 5-min cooldown |
| **Brand Room Skin** | Sponsored table background | All (opt-in) | All (opt-in) | All (opt-in) | When brand campaign active |
| **Brand Card Back** | Sponsored card back | All (opt-in) | All (opt-in) | All (opt-in) | When brand campaign active |

### 8.2 Non-Intrusive Principles

1. **Never during gameplay** — no ads while cards are being played or timers are running.
2. **Always skippable** — interstitials have a 5-sec skip button (not 30-sec).
3. **Rewarded is always opt-in** — button says "Watch ad for 30 coins" with clear choice.
4. **No more than 3 ad impressions per 15-minute session** for free users.
5. **Brand skins are cosmetic** — they don't pop up; the player equips them voluntarily.
6. **Ad fatigue detection** — if a user closes 3 ads in a row within 10 min, pause ads for 30 min.

### 8.3 Revenue Estimates (Per 1 000 DAU)

| Placement | eCPM (US) | eCPM (India) | Impressions/Day | Revenue/Day (US) |
|-----------|-----------|--------------|-----------------|------------------|
| Lobby Banner | $2.50 | $0.40 | 3 000 | $7.50 |
| Game-End Native | $8.00 | $1.20 | 2 000 | $16.00 |
| Rewarded Video | $15.00 | $2.50 | 1 500 | $22.50 |
| Interstitial | $10.00 | $1.50 | 500 | $5.00 |
| Room List Native | $5.00 | $0.80 | 1 000 | $5.00 |
| **Total** | | | | **~$56/day per 1K DAU** |

---

## Part 9 — XP & Levelling System (New)

### 9.1 XP Sources

| Action | XP |
|--------|----|
| Complete a game | 100 |
| Win a game | +50 bonus |
| Win a tournament | +500 |
| Daily challenge | 200 each |
| Weekly challenge | 500 each |
| 7-day login streak | 300 |
| Refer a friend (who plays 3 games) | 1 000 |

### 9.2 Level Curve

| Level | Total XP Needed | Unlock |
|-------|-----------------|--------|
| 1-5 | 500/level | Basic emotes |
| 6-10 | 750/level | Card skin "Beginner's Lucky" |
| 11-20 | 1 000/level | Room theme "Seasoned Player" |
| 21-30 | 1 500/level | Avatar frame "Veteran" |
| 31-50 | 2 000/level | Animated effects on profile |
| 50+ | 2 500/level | "Legend" title + prestige badge each 10 levels |

Max users earn 20% bonus XP from all sources.

---

## Part 10 — Referral System (New)

### 10.1 Mechanism

1. Each player has a unique 6-character referral code (e.g., `RAJ42X`).
2. Sharing via deep link: `gameplatform.app/invite/RAJ42X`.
3. New player installs + plays 3 games → both players receive rewards.

### 10.2 Rewards

| Milestone | Referrer Gets | New Player Gets |
|-----------|---------------|-----------------|
| Friend installs | 100 coins | 200 coins (welcome bonus) |
| Friend plays 3 games | 200 coins + 10 gems | 100 coins |
| Friend reaches level 5 | 300 coins + 20 gems | Exclusive "Friendly" avatar frame |
| Friend subscribes (Pro/Max) | 500 coins + 50 gems | — |

### 10.3 Limits

- Max 20 referral rewards per month (anti-abuse).
- Referral code valid for 30 days.
- Self-referral detection via device fingerprint + IP.

---

## Part 11 — Push Notification Strategy (New)

### 11.1 Categories

| Category | Trigger | Default | Can Disable |
|----------|---------|---------|-------------|
| **Turn Reminder** | It's your turn for >60 sec | On | Yes |
| **Friend Activity** | Friend starts a game / joins lobby | On | Yes |
| **Tournament Alert** | Tournament starting in 10 min | On | Yes |
| **Daily Bonus** | Unclaimed daily bonus after 10am local | On | Yes |
| **Challenge Expiry** | Daily challenges expire in 2 hours | Off | Yes |
| **Season Pass** | New season available / season ending in 24h | On | Yes |
| **Streak Warning** | Login streak about to break (11pm local) | On | Yes |
| **Social** | Friend request, game invite | On | Yes |
| **Marketing** | New skins, events, updates | Off | Yes |

### 11.2 Frequency Caps

- Max 5 notifications per day per user.
- No notifications between 10pm and 8am local time (unless turn reminder).
- "Friend Activity" limited to 3/day to avoid spam.

---

## Part 12 — Updated Database Additions

```sql
-- ============================================
-- NEW TABLES for Product Strategy v2
-- ============================================

-- Daily / Weekly Challenges
CREATE TABLE challenges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type TEXT NOT NULL CHECK (type IN ('daily', 'weekly')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  xp_reward INT NOT NULL DEFAULT 200,
  coin_reward INT NOT NULL DEFAULT 25,
  gem_reward INT NOT NULL DEFAULT 0,
  condition JSONB NOT NULL,  -- {"type": "win_games", "game_type": "any", "count": 2}
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_challenges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  challenge_id UUID NOT NULL REFERENCES challenges(id),
  progress INT DEFAULT 0,
  target INT NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  UNIQUE(user_id, challenge_id, assigned_at::date)
);

-- XP & Levelling
ALTER TABLE profiles ADD COLUMN xp INT DEFAULT 0;
ALTER TABLE profiles ADD COLUMN level INT DEFAULT 1;
ALTER TABLE profiles ADD COLUMN xp_to_next_level INT DEFAULT 500;

-- Season Pass
CREATE TABLE seasons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  premium_gem_cost INT DEFAULT 500,
  rewards JSONB NOT NULL,  -- [{level: 1, free: {...}, premium: {...}}]
  is_active BOOLEAN DEFAULT FALSE
);

CREATE TABLE user_season_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  season_id UUID NOT NULL REFERENCES seasons(id),
  current_level INT DEFAULT 0,
  current_xp INT DEFAULT 0,
  has_premium BOOLEAN DEFAULT FALSE,
  claimed_rewards JSONB DEFAULT '[]',
  UNIQUE(user_id, season_id)
);

-- Referrals
CREATE TABLE referrals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_id UUID NOT NULL REFERENCES profiles(id),
  referred_id UUID NOT NULL REFERENCES profiles(id),
  referral_code TEXT NOT NULL,
  status TEXT DEFAULT 'installed' CHECK (status IN ('installed', 'played_3', 'level_5', 'subscribed')),
  rewards_claimed JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(referred_id)  -- each user can only be referred once
);

ALTER TABLE profiles ADD COLUMN referral_code TEXT UNIQUE;

-- Notification Preferences
CREATE TABLE notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  turn_reminder BOOLEAN DEFAULT TRUE,
  friend_activity BOOLEAN DEFAULT TRUE,
  tournament_alert BOOLEAN DEFAULT TRUE,
  daily_bonus BOOLEAN DEFAULT TRUE,
  challenge_expiry BOOLEAN DEFAULT FALSE,
  season_pass BOOLEAN DEFAULT TRUE,
  streak_warning BOOLEAN DEFAULT TRUE,
  social BOOLEAN DEFAULT TRUE,
  marketing BOOLEAN DEFAULT FALSE,
  quiet_hours_start TIME DEFAULT '22:00',
  quiet_hours_end TIME DEFAULT '08:00'
);
```

---

## Part 13 — Updated Code (Subscription Tier Comparison)

Replace the `TierBenefits` class in `13-monetization-ads.md` with:

```dart
class TierBenefits {
  final SubscriptionTier tier;
  final bool bannerAdsEnabled;
  final bool interstitialAdsEnabled;
  final bool rewardedAdsOptIn;       // All tiers can opt-in
  final bool voiceChatEnabled;
  final int voiceChatLimitSeconds;   // 0 = unlimited; 120 = 2 min teaser
  final int monthlyCoinBonus;
  final int monthlyGemBonus;
  final int maxPrivateRoomsPerDay;   // -1 = unlimited
  final int maxRoomSize;
  final bool priorityMatchmaking;
  final bool customRoomRules;
  final int friendListCap;           // -1 = unlimited
  final int spectatorSlots;
  final bool seasonPassPremium;
  final double seasonXpMultiplier;   // 1.0 = normal; 1.2 = 20% bonus
  final double tournamentGemDiscount; // 0.0, 0.10, 0.25
  final bool detailedStats;
  final bool exportableStats;
  final String? profileBadge;
  final String? leaderboardFrame;

  // ... constructor and static instances for free, pro, max
}
```

---

## Part 14 — Silent Rooms & Social Mode Settings (New)

### 14.1 Room Social Modes

When creating or joining a room, the host selects a **Social Mode** that controls what communication channels are active:

| Mode | Text Chat | Voice Chat | Emotes | Floating Bubbles | Use Case |
|------|-----------|------------|--------|-------------------|----------|
| **Full** (default) | Yes | Yes | Yes | Yes | Friends playing together, casual lobbies |
| **Chat Only** | Yes | No | Yes | Yes | Casual play without voice commitment |
| **Silent** | No | No | Emotes only (5 quick reactions) | Emote bubbles only | Focused competitive play, strangers, introverts |
| **Focus** | No | No | No | No | Pure gameplay, tournament finals, ranked matches |

### 14.2 Room Creation Flow (Updated)

```
┌────────────────────────────────────────────┐
│  Create Room                          ✕    │
│                                            │
│  Game:  [Oh Hell ▼]                        │
│  Players:  [4 ▼]    Private: [Toggle]      │
│  Rules:  [Standard ▼]                      │
│                                            │
│  ── Social Mode ──────────────────────     │
│  ┌──────┐ ┌──────────┐ ┌──────┐ ┌─────┐  │
│  │ Full │ │ Chat Only│ │Silent│ │Focus│   │
│  │  ✓   │ │          │ │      │ │     │   │
│  └──────┘ └──────────┘ └──────┘ └─────┘   │
│                                            │
│  Full: Voice, text chat, and emotes        │
│                                            │
│  [Create Room]                             │
└────────────────────────────────────────────┘
```

### 14.3 Room List Indicators

Room cards in the lobby show a small icon indicating social mode:

- 🔊 Full — speaker icon
- 💬 Chat Only — speech bubble
- 🔇 Silent — muted icon
- 🎯 Focus — target/crosshair icon

Players can **filter rooms by social mode** in the lobby search. This is important — many players specifically seek silent rooms to avoid toxic voice chat or distractions.

### 14.4 Database Changes

```sql
-- Add social_mode to room settings
CREATE TYPE room_social_mode AS ENUM ('full', 'chat_only', 'silent', 'focus');

ALTER TABLE game_rooms ADD COLUMN social_mode room_social_mode DEFAULT 'full';

-- Personal preference (auto-applied when creating rooms)
ALTER TABLE profiles ADD COLUMN preferred_social_mode room_social_mode DEFAULT 'full';
```

### 14.5 Matchmaking Integration

When using Quick Play / Auto-Match, the player's `preferred_social_mode` is used as a **soft preference** — the matchmaker tries to place them in a matching room but will fall back to any available room after 15 seconds. A toast warns: "Joining a Full room (no Silent rooms available)."

---

## Part 15 — Floating Chat Bubbles (New)

### 15.1 Concept

Instead of hiding chat in a side panel, messages appear as **floating speech bubbles above the sender's avatar** on the game screen. This makes communication feel natural and integrated into gameplay without requiring players to open a chat panel.

### 15.2 Bubble Behaviour

| Property | Value |
|----------|-------|
| **Appears** | Above the sender's PlayerNode avatar |
| **Max width** | 140px (truncates with "..." if longer) |
| **Duration** | Auto-dismiss after 4 seconds |
| **Animation in** | Scale(0.7→1) + fadeIn, 250ms ease-out |
| **Animation out** | FadeOut + translateY(-8px), 300ms |
| **Stacking** | Max 2 bubbles per player; oldest dismissed when 3rd arrives |
| **Tap action** | Tap bubble to open full chat panel |
| **Position** | Offset 8px above avatar, centred horizontally |
| **Z-index** | Above player nodes, below modals |

### 15.3 Bubble Types

**Text message bubble:**
```
    ┌─────────────────┐
    │  Nice play! 👏  │  ← white bg, textDark colour
    └────────┬────────┘
             ▼
          [Avatar]
```

**Emote-only bubble** (larger, no background):
```
         😂
       (48px)
      [Avatar]
```

**System/quick-phrase bubble** (accent tint):
```
    ┌─────────────────┐
    │   Good luck!    │  ← accentSoft bg tint
    └────────┬────────┘
             ▼
          [Avatar]
```

### 15.4 Flutter Implementation Sketch

```dart
class FloatingChatBubble extends StatefulWidget {
  final String message;
  final bool isEmoteOnly;
  final bool isQuickPhrase;
  final VoidCallback? onTap;

  const FloatingChatBubble({
    super.key,
    required this.message,
    this.isEmoteOnly = false,
    this.isQuickPhrase = false,
    this.onTap,
  });

  @override
  State<FloatingChatBubble> createState() => _FloatingChatBubbleState();
}

class _FloatingChatBubbleState extends State<FloatingChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000), // total lifecycle
      vsync: this,
    );

    // Enter: 0-6% (250ms of 4000ms)
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 6),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 87),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 7),
    ]).animate(_controller);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 6),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 87),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 7),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmoteOnly) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Opacity(
          opacity: _opacityAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Text(widget.message, style: TextStyle(fontSize: 48)),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Opacity(
        opacity: _opacityAnim.value,
        child: Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              constraints: BoxConstraints(maxWidth: 140),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isQuickPhrase
                    ? Color(0xFFF5E6D0) // warm accent tint
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8, offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: Color(0xFF241810),
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### 15.5 Integration with Social Modes

| Social Mode | Floating Bubbles |
|-------------|------------------|
| Full | Text + emote + quick-phrase bubbles |
| Chat Only | Text + emote + quick-phrase bubbles |
| Silent | Emote bubbles only (the 5 quick reactions) |
| Focus | No bubbles at all |

### 15.6 Player Preference Override

Individual players can toggle floating bubbles off in Settings → Gameplay → "Show chat bubbles" (default: on). This is separate from the room's social mode — a player in a "Full" room can hide bubbles locally while still reading the side-panel chat.

---

## Summary of All Changes from Original Design

| Area | Before | After |
|------|--------|-------|
| Pro price | $4.99/mo | $3.99/mo |
| Max price | $9.99/mo | $7.99/mo |
| Free monthly coins | 100 | 200 |
| Free voice chat | None | 2 min/game teaser |
| Coin economy | Flat earn/spend | Balanced sources + sinks with inflation control |
| Gem IAP | Not defined | 5 packs from $0.99 to $49.99 |
| Friends UX | Basic friend list | Live activity strip + quick-join + spectate + invite |
| Ads | 6 placements | 7 placements with fatigue detection + frequency caps |
| Progression | None | XP + Levels + Season Pass |
| Challenges | Daily bonus only | 3 daily + 5 weekly challenges |
| Referrals | None | 4-tier referral reward ladder |
| Notifications | Boolean toggle | 9 categories with frequency caps + quiet hours |
| Payments | RevenueCat only | RevenueCat + Stripe (web) + Razorpay (India) + regional wallets |
| Localisation | "No hardcoded strings" | 7 priority languages incl. RTL |
| Accessibility | Minimal mention | Screen reader, reduced motion, colour-blind, scalable text |
| Offline mode | None | Vs-bot offline with reconnect sync |
| Onboarding | None | 3-step guided first experience |
| Room social modes | None (all rooms have full chat) | 4 modes: Full, Chat Only, Silent, Focus |
| In-game chat | Hidden in side tab | Floating speech bubbles above avatars + side panel |
