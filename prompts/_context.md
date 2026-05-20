# ═══════════════════════════════════════════════════════════════
# GAME PLATFORM — UNIFIED CONTEXT FILE
# ═══════════════════════════════════════════════════════════════
#
# Load this single file at the start of EVERY Claude Code session.
# It combines: 00-design-system.md + 00-master-prompt.md + 20-product-strategy.md
#
# Last updated: 2026-02-26
# ═══════════════════════════════════════════════════════════════


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION A — DESIGN SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Design System Reference — Game Platform

> **Purpose**: Feed this file at the start of any new chat to maintain visual and code consistency across all screens. Covers the full design language, component patterns, and Flutter implementation conventions established during UI/UX design sessions.

---

## Visual Language

### Theme: "Refined Crystal"
A premium digital card-table aesthetic. Warm felt green surfaces, luminous frosted glass panels, and gold accents. The background recedes; game content is always the focal point.

### Core Principle
**No decorative boxes around players or UI elements unless absolutely necessary.** Elements float directly on the felt with drop shadows providing depth. Glass panels are reserved for HUD components, modals, and info chips — not every widget.

---

## Colour Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `feltDark` | `#122e1d` | Screen background base |
| `feltMid` | `#1d4a2e` | Primary surface |
| `feltLight` | `#2a6641` | Highlight areas |
| `accent` | `#C47B2B` | Gold — active states, CTAs, trump indicators |
| `accentSoft` | `#E8A84F` | Hover states, glow colours |
| `accentGlow` | `rgba(196,123,43,0.22)` | Box shadows, ambient glows |
| `glass` | `rgba(255,255,255,0.52)` | Glass panel backgrounds |
| `glassBorder` | `rgba(255,255,255,0.72)` | Glass panel borders |
| `textDark` | `#241810` | Text on glass surfaces |
| `textMuted` | `#9c7d62` | Secondary text on glass |
| `textOnFelt` | `rgba(255,255,255,0.90)` | Primary text on felt |
| `textFeltMuted` | `rgba(255,255,255,0.50)` | Secondary text on felt |
| `success` | `#27ae60` | On-track bids, positive states |
| `danger` | `#e74c3c` | Busted bids, errors |
| `cardBg` | `#FFFFFF` | Playing card background |
| `cardRed` | `#c0392b` | Hearts / Diamonds |
| `cardBlack` | `#1a1a2a` | Spades / Clubs |
| `avatarBg` | `linear(#f0e8da → #e5d4bc)` | Avatar circle fill |

---

## Typography

| Role | Font | Size | Weight | Colour |
|------|------|------|--------|--------|
| Screen title | DM Serif Display | 24–28px | Regular | white |
| Card rank (hand) | DM Serif Display | 18px | Regular | card colour |
| Card rank (trick) | DM Serif Display | 16px | Regular | card colour |
| Score numerals | DM Serif Display | 20px | Regular | `textDark` |
| Player name | DM Sans | 9–11px | SemiBold | `textFeltMuted` |
| Body / labels | DM Sans | 10–13px | Medium/SemiBold | context |
| Bid pill text | DM Sans | 10px | Bold | status colour |
| CTA buttons | DM Sans | 11–13px | SemiBold | white |

---

## Glass Morphism Recipe

Applied to: HUD pills, toasts, score panels, modals, emoji bars, side tab buttons.

**CSS:**
```css
background: rgba(255,255,255,0.52);
border: 1px solid rgba(255,255,255,0.72);
backdrop-filter: blur(18px) saturate(1.35);
box-shadow: 0 4px 20px rgba(60,40,20,0.10), 0 1px 3px rgba(255,255,255,0.55) inset;
```

**Flutter (`BackdropFilter` + `ClipRRect`):**
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(radius),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.52),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.72)),
        boxShadow: [
          BoxShadow(color: Color(0x1A3C2814), blurRadius: 20, offset: Offset(0,4)),
        ],
      ),
      child: child,
    ),
  ),
)
```

---

## Component Library

### GlassPill
Rounded pill (borderRadius: 100) with glass fill. Used for: GameTitle, RoundInfo, Toast, EmojiBar.
```dart
// Padding: horizontal 10–14px, vertical 5–6px
// Always wraps content in a Row with gap 5–6px
```

### PlayerNode
Floating avatar + name + bid pill. **No containing box.**
```dart
Column(
  children: [
    _Avatar(emoji, size: 40–44, isActive, hasPlayed, isDealer),
    Text(name, style: TextStyle(fontSize: 9, color: Colors.white54)),
    BidPill(won: p.won, bid: p.bid),
  ]
)
```

**Avatar states:**
- **Idle**: plain gradient circle, subtle drop shadow
- **Active turn**: `Border.all(color: accent, width: 2.5)` + gold box-shadow + pulsing dot (Rive or AnimationController)
- **Has played this trick**: green ✓ badge at bottom-right of avatar (`Positioned`)

**BidPill colour logic:**
```dart
Color get pillColor {
  if (won > bid)  return danger;   // busted
  if (won == bid) return success;  // making
  return Colors.white54;           // neutral
}
```

### PlayingCard
**Trick cards**: 56×80px, borderRadius 8, DM Serif Display ranks.
**Hand cards**: 62×90px, borderRadius 9, DM Serif Display ranks.

Card states:
- **Winning**: `Border.all(color: accent, width: 2.5)` + gold box-shadow, highest z-index
- **Trump**: gold border `rgba(196,123,43,0.55)` + small ♦ pip badge at bottom-right
- **Invalid/unplayable**: `opacity: 0.42`, `ColorFilter.matrix(saturation 0.4)`
- **Selected (hand)**: gold ring + `translateY(-20px)` lift

**Avatar badge on trick cards**: 20×20px circle, `Positioned(top: -9)`, same emoji as player pod.

### CardFan (hand)
```dart
// Spread: min(36, 210 / (n-1))px between card centres
// Rotation: (index - (n-1)/2) * 4.5 degrees
// Y offset: abs(offset) * 2.5px drop for outer cards
// Selected card: translateY(-20px) + gold ring
// Invalid card: opacity 0.42
```

### TrickZone (card grid)
Cards laid out in up to 2 rows, centred in zone.
```dart
// Row 1: ceil(n/2) cards
// Row 2: floor(n/2) cards
// Card gap: 8px
// Per-card rotation: [-3°, 4°, -2°, 3°, -4°, 2°, -3°, 4°]
// Avatar badge floats 9px above card top edge
```

### TurnTimer
Circular progress ring, animated drain over turn duration.
```dart
// Size: 38×38px
// Track: rgba(255,255,255,0.10), strokeWidth 3
// Fill: accent colour, strokeWidth 3, strokeLinecap round
// Number: DM Serif Display 12px white centre
// Flutter: CustomPainter + AnimationController
```

### BiddingModal
Glass modal, borderRadius 22, padding 22×20.
```dart
// Oh Hell specific: forbidden bid number struck-through and disabled
// Bid grid: GridView, up to 6 columns
// forbiddenBid = totalCards - sumOfOtherBids  (dealer constraint)
// Confirm button: full-width, accent fill, borderRadius 13
```

---

## Screen Layout — In-Game (Card Games)

```
┌─────────────────────────────────────┐  ← 393px
│  [HUD: GamePill · RoundInfo · Menu] │  top: 40px
│  [Toast]          [Timer]           │  top: 92px
│                                     │
│  [Top row: 1–3 PlayerNodes]         │  top: 122px
│                                     │
│ [Left]        TRICK ZONE      [Right│  centre
│ [Col ]    ┌─────────────────┐  [Col ]
│ [2   ]    │  Card grid      │  [2  ]
│ [nodes]   │  (56×80 cards)  │  [nodes]
│           │  avatar badges  │
│           └─────────────────┘
│                                     │
│  [VoiceCluster]       [SideTabs]   │  bottom: 190px
│         [EmojiBar]                 │  bottom: 184px
│  ─────────────────────────────────  │
│  [MyAvatar · Name]    [BidStatus]  │  HandMeta
│  [     Card Fan (7 cards)        ] │  130px tall
└─────────────────────────────────────┘
```

**Player layout by count:**
| Count | Top row | Left col | Right col |
|-------|---------|----------|-----------|
| 3–4P  | all opponents | — | — |
| 5–6P  | n-3 players | 1 | 1 |
| 7–8P  | 3 players | 2 | 2 |

Side column nodes use slightly smaller avatars (36px vs 40px).

---

## HUD Components

### GamePill (top-left)
`[IconBox · "GameName"]` — gradient icon box (accent→accentSoft), 24×24, borderRadius 7.

### RoundInfo (top-centre)
`["Round N" · TrumpSuit · "X cards"]` — glass pill.

### MenuBtn (top-right)
34×34 glass circle, `···` icon.

### Toast
Glass pill, centred below HUD, contextual messages:
- Your turn: `"✨ Your turn — play a card"`
- Waiting: `"⏳ Waiting for [Name]…"`
- Trick won: `"🏆 [Name] wins this trick!"`

---

## Floating UI (always visible during play)

| Element | Position | Description |
|---------|----------|-------------|
| VoiceCluster | left: 10, bottom: 190 | Mic + mute buttons, glass, 34×34 each |
| SideTabs | right: 10, bottom: 190 | Game/Chat/Score tabs, 34×34 each |
| EmojiBar | bottom: 184, centred | Glass pill, 5 emoji buttons 29×29 |

**Speaking indicator**: mic button gets `rgba(46,213,115,0.20)` fill + green border + pulse animation.

---

## Animation Conventions

| Animation | Style | Duration |
|-----------|-------|----------|
| Card played → trick zone | Slide from player direction + scale | 300ms, ease-out |
| Card selected in hand | translateY(-20px) | 220ms, cubic-bezier(0.34,1.56,0.64,1) |
| Card entry in trick | Fade + translateY(-12px) scale(0.88→1) | 350ms staggered 60ms |
| Active player pulse dot | Scale 1→0.65 opacity loop | 1200ms ease-in-out |
| Modal entry | scale(0.88)→1 translateY(16px)→0 | 350ms cubic-bezier(0.34,1.56,0.64,1) |
| Emoji float | translateY(-140px) scale(1→0.5) fade | 1400ms ease |
| Toast entry | fadeUp + scale(0.92→1) | 400ms cubic-bezier(0.34,1.56,0.64,1) |
| Floating chat bubble enter | Scale(0.7→1) + fadeIn | 250ms ease-out |
| Floating chat bubble exit | FadeOut + translateY(-8px) | 300ms |

---

## Game-Specific Notes

### Oh Hell
- **BidPill is mandatory** on every player node — it's the core game information
- **Forbidden bid rule**: dealer's bid cannot make total equal to cards dealt. Show forbidden number struck-through in modal with warning note
- **BidStatus** shown prominently next to MyAvatar: `"2 / 3 bid"` with green/red colour
- No card-count display on opponent pods

### General Card Games (Twenty-Nine, Hearts, Spades etc.)
- Trump banner in RoundInfo pill
- ScorePanel: `[Us: 14 | Them: 11]` glass pill
- Trick counter can be omitted from play area (shown in score panel if needed)

---

## File Conventions (Flutter)

```
lib/features/game/presentation/
├── widgets/
│   ├── player_node.dart          # Floating avatar + name + bid pill
│   ├── trick_zone.dart           # Card grid with avatar badges
│   ├── card_fan.dart             # Hand card fan
│   ├── playing_card.dart         # Individual card widget
│   ├── bid_pill.dart             # Coloured bid status chip
│   ├── glass_pill.dart           # Reusable glass container
│   ├── turn_timer.dart           # Circular progress timer
│   ├── bidding_modal.dart        # Oh Hell bid modal
│   └── floating_chat_bubble.dart # Speech bubble above avatars
└── screens/
    └── oh_hell_screen.dart       # Full game screen
```

All widgets use `const` constructors where possible. State via Riverpod providers. No hardcoded colours — reference `AppColors` constants class.


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION B — MASTER BUILD PROMPT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Game Platform - Master Build Prompt

> **Purpose**: This is the master orchestration prompt for building a complete multiplayer game platform supporting card games (Twenty-Nine, Oh Hell, Bridge, Hearts, Spades, Rummy) and board games (Chess, Ludo, Sequence). Feed these prompts to Claude Code in sequence.

## Project Vision

A modern, multiplayer game platform with:
- **Glass morphism UI** with blur effects, transparency, and subtle gradients
- **Real-time multiplayer** via Supabase Realtime
- **Hot-patchable rules** via Shorebird + server-side configs
- **Rich animations** for immersive gameplay
- **Social features** including text chat, voice chat, floating chat bubbles, democratic moderation, and 4 social modes (Full / Chat Only / Silent / Focus)
- **Monetization** through subscriptions ($3.99 Pro / $7.99 Max), cosmetics, coin/gem economy, season pass, and non-intrusive ads
- **Tournaments** with single/double elimination, round robin, and Swiss formats
- **Favorites & History** for quick access to preferred games and replay functionality
- **Friends Activity** with live status strip, quick-join, spectator mode, and game invites
- **Progression** with XP, levels, daily/weekly challenges, and referral rewards
- **Cross-platform** Flutter app (iOS, Android, Web, Desktop)
- **Test-driven development** with Playwright E2E testing across 10+ device profiles

---

## Prompt Execution Order

Execute these prompts in sequence. Each builds upon the previous. **Always load this `_context.md` file first in every session.**

| Order | File | Description | Est. Scope |
|-------|------|-------------|------------|
| 1 | `01-project-setup.md` | Monorepo, dependencies, tooling | Foundation |
| 2 | `02-database-schema.md` | Supabase tables, RLS, migrations (merge with Part 12 & 14 of product strategy) | Backend |
| 3 | `03-testing-strategy.md` | Testing pyramid, Playwright E2E | Testing |
| 4 | `04-game-core-package.md` | Abstract game framework | Core Package |
| 5 | `05-card-game-implementations.md` | Twenty-Nine, Oh Hell, Hearts, etc. | Game Logic |
| 6 | `06-board-game-implementations.md` | Chess, Ludo, Sequence | Game Logic |
| 7 | `07-bot-strategies.md` | AI players for all games (must work offline) | AI |
| 8 | `08-flutter-app-structure.md` | App shell, routing, theming (add challenges, season pass, referral, friends modules) | UI Foundation |
| 9 | `09-glass-ui-components.md` | Glass morphism design system (add FloatingChatBubble, SocialModeIndicator, FriendActivityCard) | UI Components |
| 10 | `10-animation-system.md` | All gameplay animations (add chat bubble animations) | Animations |
| 11 | `11-game-screens.md` + `19-in-game-screen.md` | Game-specific UI screens (add floating bubbles, social mode enforcement, spectator view) | Game UI |
| 12 | `12-social-features.md` | Chat, voice, moderation (add silent rooms, floating bubbles, friends activity, quick-join, spectator separation) | Social |
| 13 | `13-monetization-ads.md` | Subscriptions, skins, ads (use revised tiers, economy, ad fatigue, season pass from this file) | Business |
| 14 | `14-assets-skins-system.md` | Card/room skins, brand customization | Assets |
| 15 | `15-edge-functions.md` | Server-side validation, matchmaking (add join-room, claim-daily-bonus, claim-challenge, referral, season-reward functions) | Backend |
| 16 | `16-shorebird-updates.md` | OTA updates, feature flags | DevOps |
| 17 | `17-favorites-and-history.md` | Favorite games, game history, replays | Features |
| 18 | `18-tournaments.md` | Tournament brackets, matchmaking (use coin economy for entry fees, tier discounts) | Features |

---

## Architecture Principles

### 1. Separation of Concerns
```
packages/
├── game_core/          # Abstract interfaces, no game logic
├── game_twenty_nine/   # Concrete 29 implementation
├── game_oh_hell/       # Concrete Oh Hell implementation
├── game_hearts/        # ... and so on
├── game_chess/         # Board game packages
├── bot_strategies/     # AI for all games
├── social_core/        # Chat, voice, moderation, floating bubbles
└── monetization/       # IAP, ads, subscriptions, economy, season pass

apps/
└── flutter_app/        # The main application
    ├── lib/
    │   ├── core/       # App-wide services, DI, config
    │   ├── features/   # Feature-based modules
    │   │   ├── auth/
    │   │   ├── home/
    │   │   ├── lobby/
    │   │   ├── game/
    │   │   ├── profile/
    │   │   ├── shop/
    │   │   ├── leaderboard/
    │   │   ├── friends/        # NEW: activity feed, quick-join
    │   │   ├── challenges/     # NEW: daily/weekly challenges
    │   │   ├── season_pass/    # NEW: season pass UI
    │   │   └── referral/       # NEW: referral system
    │   └── shared/     # Shared widgets, utils
    └── assets/         # Images, audio, animations
```

### 2. Server-Side Rule Authority
- Game rules are defined in packages but **configurable via server**
- `game_configs` table stores tunable parameters
- Shorebird enables hot-patching of rule logic
- Edge functions validate moves server-side (anti-cheat)

### 3. Type-Safe Generics
All game systems use generics for type safety:
```dart
abstract class GameRules<TState extends GameState, TMove extends GameMove> {
  TState applyMove(TState state, TMove move);
  List<TMove> getValidMoves(TState state, String playerId);
}
```

### 4. Real-Time First
- Supabase Realtime for game state sync
- Presence for player online status + friends activity
- Optimistic UI updates with server reconciliation

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter 3.24+ |
| State Management | Riverpod 2.5+ |
| Navigation | GoRouter 14+ |
| Backend | Supabase (Postgres + Realtime + Auth + Edge Functions) |
| OTA Updates | Shorebird |
| Animations | Rive + Flutter Animations |
| Voice Chat | LiveKit or Agora |
| Analytics | PostHog or Mixpanel |
| Crash Reporting | Sentry |
| Ads | Google AdMob (non-intrusive) |
| IAP | RevenueCat |
| Web Payments | Stripe + Razorpay (India) |

---

## Key Design Decisions

### Why Supabase?
- Postgres with Row-Level Security for data protection
- Realtime subscriptions for multiplayer sync
- Edge Functions for server-side validation
- Built-in auth with social providers

### Why Shorebird?
- Hot-patch game rules without app store updates
- A/B test new rule variants
- Instant bug fixes for game logic
- Feature flags for gradual rollouts

### Why Glass Morphism?
- Modern, premium feel
- Works well in both light and dark modes
- Allows game content to remain focal point
- Differentiates from traditional card game apps

---

## File Naming Conventions

```
# Dart files
snake_case.dart

# Feature structure
features/
  feature_name/
    data/           # Repositories, data sources
    domain/         # Entities, use cases (if needed)
    presentation/   # Screens, widgets, providers

# Assets
assets/
  cards/{skin_name}/     # Card face images
  boards/{game_name}/    # Board backgrounds
  rooms/{skin_name}/     # Table/room backgrounds
  audio/{game_name}/     # Game-specific sounds
  animations/            # Rive files
```

---

## Quality Standards

1. **No hardcoded strings** - Use constants or l10n (7 priority languages: English, Hindi, Portuguese, Arabic RTL, Spanish, Bahasa, Thai)
2. **No magic numbers** - Use named constants
3. **Error handling** - Always handle errors gracefully
4. **Accessibility** - Screen reader support, reduced motion mode, colour-blind modes, scalable text, sufficient contrast
5. **Performance** - Lazy loading, pagination, caching
6. **Offline support** - Bot play works offline; state syncs on reconnect
7. **Testing Pyramid**:
   - Unit tests for game logic (rules, moves, scoring)
   - Widget tests for UI components
   - Golden tests for visual regression
   - Integration tests for feature flows
   - Playwright E2E tests across 10+ device profiles


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTION C — PRODUCT STRATEGY & MONETIZATION BLUEPRINT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Product Strategy & Monetization Blueprint

> **Purpose**: Comprehensive product strategy covering gap analysis, refined subscription tiers, coin/gem economy, friends-activity UX, global payments, and ad-placement design. This section is the source of truth — it overrides values in prompts 12–14 where they conflict.

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

### 2.2 Country-Specific Pricing

| Region | Pro (monthly) | Max (monthly) | Pro (annual) | Max (annual) |
|--------|---------------|---------------|--------------|--------------|
| **US / Canada** | $3.99 | $7.99 | $38.99 | $74.99 |
| **EU / UK** | €3.99 / £3.49 | €7.99 / £6.99 | €37.99 / £34.99 | €72.99 / £67.99 |
| **India** | ₹149 (~$1.75) | ₹299 (~$3.50) | ₹1 399 | ₹2 799 |
| **Brazil** | R$12.90 | R$24.90 | R$119.90 | R$229.90 |
| **SE Asia (ID/PH/TH)** | $1.49 equiv. | $2.99 equiv. | $13.99 | $27.99 |
| **Middle East (AE/SA)** | AED 14.99 | AED 29.99 | AED 139.99 | AED 279.99 |

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
| Daily login | 15–60 | Scales with consecutive days |
| Win a game | 20 | 10 for 2nd place; 5 for loss (participation) |
| Complete daily challenge (×3) | 25 each = 75 | e.g., "Win 2 Hearts games" |
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
| Enter casual tournament | 50–200 coins | Volume drain |
| Enter ranked tournament | 100–500 coins | Higher stakes |
| Buy basic emote | 500 coins | Cosmetic |
| Buy basic card skin | 2 000 coins | ~7-10 days of play |
| Buy basic room skin | 3 000 coins | ~12-15 days |
| Room creation (custom rules) | 25 coins | Micro-sink |
| Re-roll daily challenge | 30 coins | Convenience |
| Undo last move (casual only) | 50 coins | Fun convenience |
| Gift emote to friend | 150 coins | Social spend |

### 3.5 Gem Sinks

| Sink | Cost | Purpose |
|------|------|---------|
| Season Pass (premium track) | 500 gems | ~$5 equivalent; 30-day content |
| Premium card skin | 200–400 gems | Animated / limited-edition |
| Premium room theme | 300–600 gems | High-fidelity environments |
| Animated avatar frame | 150 gems | Profile flair |
| Tournament fast-pass | 50 gems | Convenience |
| Name-change token | 100 gems | Rare use |

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
3. **No pay-to-win**: Coins/gems never buy gameplay advantage.
4. **Seasonal reset**: Tournament leaderboards reset each season; coin balances persist.
5. **Audit table**: Every transaction logged in `currency_transactions` with reason, reference_id, and balance snapshots.

---

## Part 4 — Friends Activity & Quick-Join

### 4.1 Friends Activity Strip (Home Screen)

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

**States**: 🟢 In Game (Watch), 🟡 In Lobby (Join), 🔵 Online (Invite), ⚫ Offline (dimmed)

### 4.2 Database Additions

```sql
ALTER TABLE profiles ADD COLUMN current_activity JSONB DEFAULT NULL;
-- {"type": "in_game", "game_type": "oh_hell", "room_id": "...", "room_code": "ABCD", "round": 3, "spectatable": true, "joinable": false}
CREATE INDEX idx_profiles_activity ON profiles USING GIN (current_activity) WHERE current_activity IS NOT NULL;
```

### 4.3 Quick-Join Flow

1. Tap "Join" → `POST /join-room` edge function with `room_id`.
2. Checks: room not full, player not banned, game not started.
3. If game started → "Watch instead?" + "Notify when next game starts"
4. If room full → "Notify when seat opens?"
5. If joinable → seamless entry; toast "[Name] joined!"

### 4.4 Spectator Mode

- 30-sec delay for card games (anti-cheat); no delay for chess.
- Spectators see cards face-down except active trick.
- Spectator chat separate from player chat.
- Free: 2 slots. Pro: 5. Max: 10.

### 4.5 Invite Flow

Deep links: `gameplatform://room/ABCD` for in-app and external sharing (SMS, WhatsApp).

---

## Part 5 — Global Payment Strategy

### 5.1 Architecture

```
RevenueCat (Orchestrator)
  ├── Apple IAP (iOS)
  ├── Google Play Billing (Android)
  └── Stripe (Web) + Razorpay (India)
  → Webhook → Supabase Edge Function → Update subscription_tier + grant coins/gems
```

### 5.2 Regional Payment Methods

| Region | Subscriptions | One-Time (Gems) | Carrier Billing |
|--------|---------------|------------------|-----------------|
| **US/CA** | Apple/Google/Stripe | Apple/Google/Stripe | N/A |
| **EU/UK** | Apple/Google/Stripe | SEPA, iDEAL via Stripe | N/A |
| **India** | Google Play / Stripe+UPI Autopay | UPI / Razorpay | Jio, Airtel (phase 2) |
| **Brazil** | Google Play / Stripe+Pix | Pix / Boleto | Claro, Vivo (phase 2) |
| **SE Asia** | Google Play / Stripe+wallets | GoPay, GCash, TrueMoney | Telkomsel, Globe (phase 2) |
| **Middle East** | Apple/Google | Apple/Google / local cards | Etisalat (phase 2) |

### 5.3 Fraud Prevention

- RevenueCat flags subscription fraud.
- Server-side gem-pack validation before crediting.
- Max 5 gem purchases per 24 hours.
- Stripe Radar for web payment anomaly detection.

---

## Part 6 — Season Pass System

30-day pass with **free + premium tracks**. Premium costs 500 gems (included free for Pro/Max). Max gets 20% bonus XP.

| Level | Free Track | Premium Track |
|-------|-----------|---------------|
| 1 | 50 coins | Animated card back "Nebula" |
| 5 | 100 coins | Avatar frame "Season 1" |
| 10 | 200 coins | Exclusive card skin "Holographic" |
| 15 | 150 coins | Room theme "Midnight Casino" |
| 20 | 300 coins | Animated avatar "Champion's Glow" |
| 30 | 500 coins + badge | Legendary skin "Aurora" + Title |

**XP**: Game = 100 XP, Win = +50, Daily challenge = 200, Weekly = 500. Level-up = 1 000 XP/level.

---

## Part 7 — Daily & Weekly Challenges

**Daily (3/day)**: e.g., "Win 2 games" (25 coins), "Play 3 Oh Hell rounds" (30 coins). Re-roll for 30 coins (Pro/Max: 1 free).

**Weekly (5/week)**: e.g., "Win 10 games" (150 coins), "Invite a friend" (200 coins + 10 gems).

---

## Part 8 — Ad Placement Strategy

| Placement | Type | Free | Pro | Max | Frequency |
|-----------|------|------|-----|-----|-----------|
| Lobby Banner | 320×50 | Yes | No | No | Always in lobby |
| Game-End Card | Native | Yes | No | No | After every game |
| Rewarded Video | Fullscreen | Yes | Opt-in | Opt-in | Max 5/day, 20-min cooldown |
| Room List Native | In-list card | Yes | No | No | Every 5th room |
| Interstitial | Fullscreen | Yes | No | No | Max 2/session, 5-min cooldown |
| Brand Room/Card | Cosmetic | Opt-in | Opt-in | Opt-in | When campaign active |

**Rules**: Never during gameplay. 5-sec skip on interstitials. Ad fatigue: pause 30 min after 3 closes in 10 min.

---

## Part 9 — XP & Levelling

| Action | XP |
|--------|----|
| Complete a game | 100 |
| Win | +50 |
| Win tournament | +500 |
| Daily challenge | 200 |
| Weekly challenge | 500 |
| 7-day streak | 300 |
| Refer a friend | 1 000 |

Level curve: 500 XP/level (1-5), 750 (6-10), 1000 (11-20), 1500 (21-30), 2000 (31-50), 2500 (50+). Max users earn 20% bonus XP.

---

## Part 10 — Referral System

Referral code: 6-character. Deep link: `gameplatform.app/invite/RAJ42X`.

| Milestone | Referrer | New Player |
|-----------|----------|------------|
| Install | 100 coins | 200 coins |
| 3 games played | 200 coins + 10 gems | 100 coins |
| Level 5 | 300 coins + 20 gems | "Friendly" avatar frame |
| Subscribes | 500 coins + 50 gems | — |

Max 20 referrals/month. Self-referral detection via device fingerprint + IP.

---

## Part 11 — Push Notifications

| Category | Default | Can Disable |
|----------|---------|-------------|
| Turn Reminder (>60s) | On | Yes |
| Friend Activity | On | Yes |
| Tournament Alert (10 min before) | On | Yes |
| Daily Bonus (unclaimed after 10am) | On | Yes |
| Challenge Expiry (2h left) | Off | Yes |
| Season Pass | On | Yes |
| Streak Warning (11pm) | On | Yes |
| Social (friend req, invite) | On | Yes |
| Marketing | Off | Yes |

Max 5/day. Quiet hours 10pm-8am local. Friend Activity max 3/day.

---

## Part 12 — Database Additions (Merge with prompt 02)

```sql
-- Challenges
CREATE TABLE challenges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type TEXT NOT NULL CHECK (type IN ('daily', 'weekly')),
  title TEXT NOT NULL, description TEXT NOT NULL,
  xp_reward INT DEFAULT 200, coin_reward INT DEFAULT 25, gem_reward INT DEFAULT 0,
  condition JSONB NOT NULL, is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_challenges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  challenge_id UUID NOT NULL REFERENCES challenges(id),
  progress INT DEFAULT 0, target INT NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  assigned_at TIMESTAMPTZ DEFAULT NOW(), completed_at TIMESTAMPTZ,
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
  name TEXT NOT NULL, starts_at TIMESTAMPTZ NOT NULL, ends_at TIMESTAMPTZ NOT NULL,
  premium_gem_cost INT DEFAULT 500, rewards JSONB NOT NULL,
  is_active BOOLEAN DEFAULT FALSE
);

CREATE TABLE user_season_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  season_id UUID NOT NULL REFERENCES seasons(id),
  current_level INT DEFAULT 0, current_xp INT DEFAULT 0,
  has_premium BOOLEAN DEFAULT FALSE, claimed_rewards JSONB DEFAULT '[]',
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
  UNIQUE(referred_id)
);

ALTER TABLE profiles ADD COLUMN referral_code TEXT UNIQUE;

-- Notification Preferences
CREATE TABLE notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  turn_reminder BOOLEAN DEFAULT TRUE, friend_activity BOOLEAN DEFAULT TRUE,
  tournament_alert BOOLEAN DEFAULT TRUE, daily_bonus BOOLEAN DEFAULT TRUE,
  challenge_expiry BOOLEAN DEFAULT FALSE, season_pass BOOLEAN DEFAULT TRUE,
  streak_warning BOOLEAN DEFAULT TRUE, social BOOLEAN DEFAULT TRUE,
  marketing BOOLEAN DEFAULT FALSE,
  quiet_hours_start TIME DEFAULT '22:00', quiet_hours_end TIME DEFAULT '08:00'
);

-- Friends Activity
ALTER TABLE profiles ADD COLUMN current_activity JSONB DEFAULT NULL;
CREATE INDEX idx_profiles_activity ON profiles USING GIN (current_activity) WHERE current_activity IS NOT NULL;

-- Social Modes
CREATE TYPE room_social_mode AS ENUM ('full', 'chat_only', 'silent', 'focus');
ALTER TABLE game_rooms ADD COLUMN social_mode room_social_mode DEFAULT 'full';
ALTER TABLE profiles ADD COLUMN preferred_social_mode room_social_mode DEFAULT 'full';
```

---

## Part 13 — Updated TierBenefits Class (Overrides prompt 13)

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
}
```

---

## Part 14 — Silent Rooms & Social Modes

### Room Social Modes

| Mode | Text Chat | Voice Chat | Emotes | Floating Bubbles | Use Case |
|------|-----------|------------|--------|-------------------|----------|
| **Full** (default) | Yes | Yes | Yes | Yes | Friends, casual |
| **Chat Only** | Yes | No | Yes | Yes | No voice commitment |
| **Silent** | No | No | Emotes only | Emote bubbles only | Competitive, introverts |
| **Focus** | No | No | No | No | Tournament finals, ranked |

Room list indicators: 🔊 Full, 💬 Chat Only, 🔇 Silent, 🎯 Focus. Filterable in lobby search.

Matchmaking uses `preferred_social_mode` as soft preference; falls back after 15 sec.

---

## Part 15 — Floating Chat Bubbles

Messages appear as **speech bubbles above the sender's avatar** instead of being hidden in a side panel.

| Property | Value |
|----------|-------|
| Max width | 140px (truncates with "...") |
| Duration | Auto-dismiss after 4 seconds |
| Animation in | Scale(0.7→1) + fadeIn, 250ms ease-out |
| Animation out | FadeOut + translateY(-8px), 300ms |
| Stacking | Max 2 per player; oldest dismissed when 3rd arrives |
| Tap action | Opens full chat panel |

**Bubble types**: Text (white bg), Emote-only (48px, no bg), Quick-phrase (accentSoft tint bg).

**Social mode integration**: Full/Chat Only = all bubbles. Silent = emote bubbles only. Focus = no bubbles.

**Player override**: Settings → Gameplay → "Show chat bubbles" toggle (default: on).

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
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Opacity(
        opacity: _opacityAnim.value,
        child: Transform.scale(
          scale: _scaleAnim.value,
          child: widget.isEmoteOnly
              ? Text(widget.message, style: TextStyle(fontSize: 48))
              : GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 140),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isQuickPhrase
                          ? Color(0xFFF5E6D0)
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
