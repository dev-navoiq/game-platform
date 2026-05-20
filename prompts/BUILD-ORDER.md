# Build Order Cheatsheet — Claude Code Sessions

> **How to use**: Each session below lists the prompt files to load together. Always start by pasting the **Always-Load** files, then add the session-specific files. Claude Code can handle 3-5 full prompt files per session comfortably.

---

## Always-Load Context (Paste First in Every Session)

These three files form the source of truth. Load them at the start of **every** Claude Code session:

| File | Why |
|------|-----|
| `00-design-system.md` | Colours, typography, glass morphism recipes, component specs, animation conventions |
| `00-master-prompt.md` | Architecture principles, tech stack, monorepo structure, file naming, quality standards |
| `20-product-strategy.md` | Subscription tiers, coin economy, social modes, floating bubbles, payment strategy, all the gaps and new systems |

**Tip**: Save these three as a single combined file (e.g. `_context.md`) so you can paste one file instead of three each time.

---

## Phase 1 — Foundation (Sessions 1-2)

### Session 1: Project Scaffold + Database

**Load**: Always-Load + `01-project-setup.md` + `02-database-schema.md`

**Instructions for Claude Code**:
> Set up the monorepo per prompt 01. Then implement the database schema from prompt 02, BUT also merge in all the schema additions from `20-product-strategy.md` Parts 12 and 14. Specifically:
> - Add the `challenges`, `user_challenges`, `seasons`, `user_season_progress`, `referrals`, `notification_preferences` tables
> - Add `room_social_mode` enum and `social_mode` column on `game_rooms`
> - Add `xp`, `level`, `xp_to_next_level`, `preferred_social_mode`, `referral_code`, `current_activity` columns on `profiles`
> - Include all RLS policies and indexes from prompt 20

**Output**: Monorepo initialised, all Supabase migrations created, `supabase db reset` runs clean.

---

### Session 2: Testing Strategy

**Load**: Always-Load + `03-testing-strategy.md`

**Instructions for Claude Code**:
> Implement the testing pyramid from prompt 03. No changes from product strategy needed here — this is pure infrastructure.

**Output**: Playwright config, test helpers, device profiles, CI pipeline stubs.

---

## Phase 2 — Game Logic (Sessions 3-6)

### Session 3: Game Core Framework

**Load**: Always-Load + `04-game-core-package.md`

**Instructions for Claude Code**:
> Build the abstract game framework. Note from product strategy: game state must include `socialMode` field (full/chat_only/silent/focus) so the UI layer knows what to render.

**Output**: `packages/game_core/` with abstract interfaces, state machines, type-safe generics.

---

### Session 4: Card Games

**Load**: Always-Load + `05-card-game-implementations.md`

**Instructions for Claude Code**:
> Implement all card game rules. Pure game logic — no UI concerns here.

**Output**: `packages/game_twenty_nine/`, `game_oh_hell/`, `game_hearts/`, `game_spades/`, `game_bridge/`, `game_rummy/` with rules, scoring, and unit tests.

---

### Session 5: Board Games

**Load**: Always-Load + `06-board-game-implementations.md`

**Instructions for Claude Code**:
> Same as session 4 but for board games.

**Output**: `packages/game_chess/`, `game_ludo/`, `game_sequence/`.

---

### Session 6: Bot Strategies

**Load**: Always-Load + `07-bot-strategies.md`

**Instructions for Claude Code**:
> Implement AI players. Note: bots are critical for offline mode (mentioned in product strategy Part 1.1). Ensure bots can run fully client-side without network calls for offline play.

**Output**: `packages/bot_strategies/` with easy/medium/hard/expert for all games.

---

## Phase 3 — App Shell & UI (Sessions 7-10)

### Session 7: Flutter App Structure

**Load**: Always-Load + `08-flutter-app-structure.md`

**Instructions for Claude Code**:
> Set up the Flutter app shell. Important additions from product strategy:
> - Add `features/challenges/` module (daily/weekly challenges)
> - Add `features/season_pass/` module
> - Add `features/referral/` module
> - Add `features/friends/` module with activity feed
> - Add `core/services/notification_service.dart` with 9 notification categories
> - Add `preferred_social_mode` to user settings
> - Routing must include onboarding flow for first-time users

**Output**: App compiles, routes work, all feature module shells exist.

---

### Session 8: Glass UI Components

**Load**: Always-Load + `09-glass-ui-components.md`

**Instructions for Claude Code**:
> Build the glass morphism design system. Add these new components beyond what's in prompt 09:
> - `FloatingChatBubble` widget (spec in product strategy Part 15)
> - `SocialModeIndicator` widget (icons for Full/Chat Only/Silent/Focus)
> - `FriendActivityCard` widget (for the friends strip on home screen)
> - `DailyChallengeCard` widget
> - `SeasonPassProgressBar` widget

**Output**: Full widget library in `lib/shared/widgets/`.

---

### Session 9: Animation System

**Load**: Always-Load + `10-animation-system.md`

**Instructions for Claude Code**:
> Implement all animations from prompt 10. Add floating chat bubble animations from product strategy Part 15.2:
> - Bubble enter: Scale(0.7→1) + fadeIn, 250ms ease-out
> - Bubble exit: FadeOut + translateY(-8px), 300ms
> - Emote bubble: larger scale + float up

**Output**: Animation controllers, Rive integration, all transition animations.

---

### Session 10: Game Screens + In-Game Screen

**Load**: Always-Load + `11-game-screens.md` + `19-in-game-screen.md`

**Instructions for Claude Code**:
> Build all game-specific screens. These two prompts are tightly coupled — load both. Key additions from product strategy:
> - Floating chat bubbles above player avatars (Part 15)
> - Social mode enforcement: hide chat/voice UI in Silent/Focus modes
> - Room social mode indicator in the HUD
> - Spectator view layout (30-sec delay for card games, cards face-down)

**Output**: Complete game screens for Oh Hell, other card games, Chess, Ludo, Sequence.

---

## Phase 4 — Features (Sessions 11-14)

### Session 11: Social Features

**Load**: Always-Load + `12-social-features.md`

**Instructions for Claude Code**:
> Implement social features from prompt 12. Merge in product strategy additions:
> - Silent room / social mode enforcement (Part 14) — disable chat/voice services when room is Silent or Focus
> - Floating chat bubble integration (Part 15) — messages broadcast to bubble overlay, not just chat panel
> - Friends activity feed (Part 4) — `current_activity` JSONB field on profiles, real-time presence via Supabase Realtime
> - Quick-join flow (Part 4.3) — edge function for join validation
> - Spectator chat separation — spectators only see other spectators' messages
> - Invite flow with deep links (Part 4.5)

**Output**: `packages/social_core/` complete with chat, voice, moderation, friends activity, floating bubbles.

---

### Session 12: Monetization & Ads

**Load**: Always-Load + `13-monetization-ads.md`

**Instructions for Claude Code**:
> Implement monetization from prompt 13. Override with product strategy values:
> - Revised tier pricing: Pro $3.99, Max $7.99 (not $4.99/$9.99)
> - Revised tier benefits: free voice 2-min teaser, free 200 coins/mo, friend list caps, spectator slots, season XP multipliers (see Part 2.1 table)
> - Updated `TierBenefits` class (Part 13)
> - Gem IAP packs: 5 tiers from $0.99 to $49.99 (Part 3.6)
> - Daily login streak rewards (Part 3.3)
> - Challenge reward system (Part 7)
> - Season Pass purchase flow (Part 6)
> - Ad fatigue detection — pause after 3 closes in 10 min (Part 8.2)
> - Rewarded ad: 5/day max, 20-min cooldown, 30 coins each (Part 8.1)

**Output**: `packages/monetization/` with revised tiers, economy, ads, season pass, challenges.

---

### Session 13: Assets & Skins

**Load**: Always-Load + `14-assets-skins-system.md`

**Instructions for Claude Code**:
> Build the asset system from prompt 14. Note: brand skins now include social mode indicators and room icons (Full/Silent/Focus/Chat Only icons per Part 14.3).

**Output**: Asset management, skin loading, brand skin system, offline caching.

---

### Session 14: Edge Functions

**Load**: Always-Load + `15-edge-functions.md`

**Instructions for Claude Code**:
> Build edge functions from prompt 15. Add these from product strategy:
> - `join-room` function with validation (Part 4.3 — check room not full, game not started, player not banned)
> - `claim-daily-bonus` function with streak logic (Part 3.3)
> - `claim-challenge-reward` function with progress validation (Part 7)
> - `record-referral` function with anti-abuse (Part 10.3)
> - `grant-season-reward` function
> - Gem purchase validation — max 5 per 24h (Part 5.5)
> - Social mode enforcement in `create-room` function

**Output**: All Supabase Edge Functions deployed and tested.

---

## Phase 5 — Polish & Launch (Sessions 15-17)

### Session 15: OTA Updates & Feature Flags

**Load**: Always-Load + `16-shorebird-updates.md`

**Instructions for Claude Code**:
> Implement Shorebird OTA and feature flags. Add flags for:
> - `floating_chat_bubbles_enabled` (default: true, can kill remotely)
> - `season_pass_enabled` (for gradual rollout)
> - `silent_rooms_enabled` (for gradual rollout)
> - `referral_system_enabled`

**Output**: Shorebird integration, feature flag system, A/B testing hooks.

---

### Session 16: Favorites, History & Replay

**Load**: Always-Load + `17-favorites-and-history.md`

**Instructions for Claude Code**:
> Build favorites and history from prompt 17. No major product strategy overrides — this prompt is self-contained.

**Output**: Favorites, recent games, game replay viewer, stats dashboard.

---

### Session 17: Tournaments

**Load**: Always-Load + `18-tournaments.md`

**Instructions for Claude Code**:
> Implement tournament system from prompt 18. Add from product strategy:
> - Tournament entry fees use coin economy (Part 3.4)
> - Pro users get 10% gem discount, Max gets 25% (Part 2.1)
> - Tournament rooms default to Focus social mode for competitive integrity
> - Spectator slots scale by subscription tier

**Output**: Tournament brackets, matchmaking, prizes, tournament chat.

---

## Phase 6 — Integration Testing (Session 18)

### Session 18: End-to-End Wiring

**Load**: Always-Load + `03-testing-strategy.md`

**Instructions for Claude Code**:
> Run the full test suite. Write integration tests that verify:
> - Silent room creates correctly and suppresses chat/voice
> - Floating bubbles appear in Full/Chat Only rooms, absent in Focus
> - Coin economy: daily bonus → play game → earn coins → enter tournament → spend coins
> - Season Pass: earn XP → level up → claim rewards (free track + premium if subscribed)
> - Friends activity: go online → friends see status → quick join works
> - Rewarded ad: watch → coins credited → cooldown enforced
> - Subscription upgrade: free → pro → ads disappear, voice unlocks
> - Referral: share code → friend installs → both get rewards

**Output**: All E2E tests pass, Playwright reports clean across device profiles.

---

## Quick Reference: Which Prompt Files Each Session Loads

| Session | Always-Load | Session Files | Focus |
|---------|-------------|---------------|-------|
| 1 | 00, 00, 20 | 01, 02 | Scaffold + DB |
| 2 | 00, 00, 20 | 03 | Testing |
| 3 | 00, 00, 20 | 04 | Game core |
| 4 | 00, 00, 20 | 05 | Card games |
| 5 | 00, 00, 20 | 06 | Board games |
| 6 | 00, 00, 20 | 07 | Bots |
| 7 | 00, 00, 20 | 08 | App shell |
| 8 | 00, 00, 20 | 09 | Glass UI |
| 9 | 00, 00, 20 | 10 | Animations |
| 10 | 00, 00, 20 | 11, 19 | Game screens |
| 11 | 00, 00, 20 | 12 | Social + silent rooms + bubbles |
| 12 | 00, 00, 20 | 13 | Monetization + economy |
| 13 | 00, 00, 20 | 14 | Assets |
| 14 | 00, 00, 20 | 15 | Edge functions |
| 15 | 00, 00, 20 | 16 | OTA + flags |
| 16 | 00, 00, 20 | 17 | Favorites + history |
| 17 | 00, 00, 20 | 18 | Tournaments |
| 18 | 00, 00, 20 | 03 | E2E testing |

---

## Files NOT Loaded Individually

| File | Reason |
|------|--------|
| `20-product-strategy.md` | Loaded in EVERY session as always-load context |
| `21-ad-screens-and-friends.html` | Visual reference only — not a build prompt; keep open in browser for design reference |
| `landing.jsx` | Marketing landing page — build separately after app is complete |
| `ohell-themed.html` | Design reference mockup — already captured in design system + prompt 19 |
