# Session 11 — Social Features

## Load these files first

```
prompts/_context.md
prompts/12-social-features.md
```

---

## Context: what's already done

**Session 1 ✅** — Monorepo scaffold + Supabase schema
**Session 2 ✅** — Testing infrastructure (test stubs, CI pipeline)
**Session 3 ✅** — `packages/game_core/` fully implemented
**Session 4 ✅** — All 6 card-game packages implemented + stubs
**Session 5 ✅** — All 3 board-game packages implemented + tested (56 tests)
**Session 6 ✅** — `packages/bot_strategies/` with 33 tests, all green
**Session 7 ✅** — Flutter app structure: core infra, routing, services, feature shells, shared widgets. 58/60 tests pass.
**Session 8 ✅** — Glass UI component library: GlassTokens, upgraded GlassContainer/GlassButton, GlassCard, GlassTextField, GlassBottomSheet, GlassNavBar, GlassAppBar, FloatingChatBubble, SocialModeIndicator, FriendActivityCard, DailyChallengeCard, SeasonPassProgressBar. 58/60 tests pass.
**Session 9 ✅** — Animation system: 20 files in `lib/shared/animations/`. 58/60 tests pass.
**Session 10 ✅** — Game screens: 34 files (foundation, atomic/compound/board widgets, 8 game screens, dispatch shell). 57/60 tests pass (3 failures: 1 pre-existing lobby flow, 2 golden google_fonts network).

### Current state of `packages/social_core/`

```
packages/social_core/
├── pubspec.yaml              # deps: game_core, equatable, collection, meta
├── lib/
│   └── social_core.dart      # Empty barrel — TODO(session-11)
└── test/                     # Empty
```

The package exists but is completely empty. `pubspec.yaml` has deps on `game_core`, `equatable`, `collection`, `meta`. Dev deps: `flutter_test`, `mocktail`.

### Existing Flutter app social infrastructure

**Core services** (`lib/core/services/`):
- `chat_service.dart` — Simple wrapper: `sendMessage()` (validates length ≤500, trims), `subscribeToMessages()` — delegates to `SupabaseService`
- `supabase_service.dart` — Has `insertChatMessage()`, `subscribeToRoomMessages()`, `updateRoomSocialMode()`
- `notification_service.dart` — Stub placeholder

**Shared widgets** (`lib/shared/widgets/`):
- `floating_chat_bubble.dart` ✅ — 4-sec auto-dismiss, scale+fade anims, 3 types (text/emote/quick-phrase), `onTap`/`onDismissed` callbacks
- `social_mode_indicator.dart` ✅ — Mode icon + label in GlassContainer pill (volume_up/chat_bubble/volume_off/center_focus)
- `friend_activity_card.dart` ✅ — `FriendActivityStatus` enum (inGame/inLobby/online/offline), status dot + action button

**Game widgets** (`lib/features/game/presentation/widgets/`):
- `game_chat.dart` ✅ — Hides in Silent/Focus, TextField input, message list, local `ChatMessage` model (senderName, content, timestamp)
- `emoji_bar.dart` ✅ — 6 emojis (Full/ChatOnly), 2 (Focus), hidden (Silent)
- `player_node.dart` ✅ — Has slot for `FloatingChatBubble` above avatar

**Feature shells** (stubs only):
- `features/friends/presentation/friends_screen.dart` — Placeholder "coming in a future session"
- `features/home/presentation/home_screen.dart` — Game tile list, friends button in AppBar

**Lobby/Room screens** (basic but functional):
- `features/lobby/screens/lobby_screen.dart` — Create room button (hardcodes `socialMode: 'full'`)
- `features/lobby/presentation/room_screen.dart` — Player slots, add bot, social mode settings bottom sheet (already calls `updateRoomSocialMode`)

### Database tables for social features (all exist in schema)

| Table | Key Columns | Notes |
|-------|-------------|-------|
| `chat_messages` | room_id, user_id, content (1-500), is_spectator_chat | RLS: room members read, own insert |
| `quick_reactions` | room_id, user_id, reaction | RLS: room members read/insert |
| `mute_votes` | room_id, voter_id, target_id | Auto-mute trigger at ≥50% votes |
| `moderation_log` | action (mute/unmute/kick/ban/warn), reason, expires_at | History |
| `user_blocks` | blocker_id, blocked_id | Unique constraint |
| `friendships` | user_id, friend_id, status (pending/accepted/declined/blocked) | Both sides query via RLS |
| `notification_preferences` | 9 boolean categories + quiet_hours | Auto-created on signup |
| `profiles` | current_activity (JSONB), preferred_social_mode | Presence tracking |
| `game_rooms` | social_mode (enum: full/chat_only/silent/focus) | Room-level enforcement |

### Key providers already defined

```dart
// core/di/providers.dart
supabaseProvider          // SupabaseClient
currentUserProvider       // Provider<User?>
isLoggedInProvider        // StateProvider<bool>

// features/game/providers/game_provider.dart
gameStateProvider         // StateNotifierProvider<GameNotifier, GameState?>

// features/game/providers/game_session_providers.dart
gameTypeProvider          // StateProvider<String?>
isMyTurnProvider          // Provider<bool>
isSpectatorProvider       // Provider<bool>
```

---

## Critical fix #1: Do NOT duplicate existing widgets

Prompt 12 defines its own versions of widgets/services that already exist. Do NOT create duplicates:

| Prompt defines | Already exists at | Action |
|----------------|-------------------|--------|
| `ChatMessage` model (complex, with reactions) | `game_chat.dart` has simple `ChatMessage` | Create proper model in `social_core`, update `game_chat.dart` to import it |
| `QuickReactions` widget | `emoji_bar.dart` already handles quick reactions | Extend `emoji_bar.dart` with Supabase wiring, do NOT create a separate `QuickReactions` widget |
| `VoiceService` with LiveKit | None exists yet | Create in `social_core` but as **abstract interface + stub** — LiveKit dep is not in pubspec yet |
| `MuteVoteOverlay` widget | None exists yet | Create new, but use `GlassContainer` + `AppColors` (not raw `Colors.black.withOpacity`) |
| `FriendsRepository` | None exists yet | Create in `social_core` |
| `ModerationService` | None exists yet | Create in `social_core` |
| `FloatingChatBubble` | `lib/shared/widgets/floating_chat_bubble.dart` | Use existing — do NOT recreate |
| `SocialModeIndicator` | `lib/shared/widgets/social_mode_indicator.dart` | Use existing — do NOT recreate |
| `FriendActivityCard` | `lib/shared/widgets/friend_activity_card.dart` | Use existing — do NOT recreate |

---

## Critical fix #2: Flutter version compatibility

Flutter 3.24.0 is in use:

- **`Color.withValues()` is NOT available** — use `withOpacity()` instead
- Do NOT use `DM Serif Display` font — project uses **Poppins** (headings) + **Inter** (body) via `google_fonts`

---

## Critical fix #3: Colour alignment

Replace all generic colours in prompt 12 with project palette:

| Prompt uses | Replace with |
|-------------|-------------|
| `Colors.black.withOpacity(0.7)` | `GlassTokens` surface pattern |
| `Colors.white.withOpacity(0.15)` | `GlassTokens.surfaceOpacity` |
| `Colors.orange` | `AppColors.accent` (#C47B2B) |
| `Colors.green` | `AppColors.success` (#27ae60) |
| `Colors.red` | `AppColors.danger` (#e74c3c) |
| `Colors.grey` | `AppColors.textMuted` |
| Any glass bg/border | Via `GlassContainer` (Session 8) |

---

## Critical fix #4: Voice chat — interface only, no LiveKit dependency

The `livekit_client` package is NOT in any pubspec.yaml. Do NOT add it. Instead:

1. **Define `VoiceService` as an abstract interface** in `social_core`
2. **Create a `StubVoiceService`** that returns `VoiceStatus.disconnected` for all operations
3. **Create `VoiceState` and `VoiceParticipant` models** (these are safe — just data classes)
4. **Create the voice UI widgets** in the Flutter app that read from providers — they'll show "Voice chat coming soon" when using the stub

This keeps the architecture ready for LiveKit integration later without adding an unused dependency.

---

## Critical fix #5: social_core is a pure Dart package

`social_core` should NOT depend on `supabase_flutter` or any Flutter package. It defines:
- **Models** (ChatMessage, Friendship, MuteVote, Reaction, VoiceParticipant, etc.)
- **Abstract interfaces** (ChatRepository, FriendsRepository, ModerationRepository, VoiceService)
- **Business logic** (rate limiting, mute threshold calculation, message validation, social mode rules)

The **Supabase implementations** of these interfaces live in the Flutter app (`lib/core/services/` or `lib/features/*/data/`).

---

## Critical fix #6: Product strategy additions (from BUILD-ORDER.md)

These features from `20-product-strategy.md` must be integrated:

1. **Silent room / social mode enforcement (Part 14)** — disable chat/voice services when room is Silent or Focus. Already partially done in `game_chat.dart` and `emoji_bar.dart` — extend to the full social stack.

2. **Floating chat bubble integration (Part 15)** — messages from chat service should broadcast to the `FloatingChatBubble` overlay on each `PlayerNode`, not just the chat panel. Use existing `FloatingChatBubble` widget. Social mode rules:
   - Full: text + emote + quick-phrase bubbles
   - Chat Only: text + emote + quick-phrase bubbles
   - Silent: emote bubbles only
   - Focus: no bubbles

3. **Friends activity feed (Part 4)** — `current_activity` JSONB field on profiles tracks real-time status. Use Supabase Realtime presence. Show activity strip on home screen.

4. **Quick-join flow (Part 4.3)** — Friend taps "Join" on activity card → validate room not full/game not started → join or spectate.

5. **Spectator chat separation** — spectators see only other spectators' messages (use `is_spectator_chat` column).

6. **Invite flow with deep links (Part 4.5)** — Create invite link → send to friend → friend taps → joins room.

---

## What to build

### Wave 1: social_core package models + interfaces (~10 files)

```
packages/social_core/lib/
├── social_core.dart                    # Barrel exports
└── src/
    ├── chat/
    │   ├── chat_message.dart           # Full ChatMessage model (Equatable)
    │   ├── chat_repository.dart        # Abstract ChatRepository interface
    │   └── chat_rules.dart             # Rate limiting, validation, social mode checks
    ├── voice/
    │   ├── voice_service.dart          # Abstract VoiceService interface
    │   ├── voice_state.dart            # VoiceStatus, VoiceParticipant models
    │   └── stub_voice_service.dart     # Stub implementation (no LiveKit)
    ├── moderation/
    │   ├── mute_vote.dart              # MuteVote model + MuteVoteResult enum
    │   ├── moderation_repository.dart  # Abstract moderation interface
    │   └── report.dart                 # Report model
    ├── friends/
    │   ├── friendship.dart             # Friendship model (Equatable)
    │   ├── friend_activity.dart        # FriendActivity model (status, game info)
    │   └── friends_repository.dart     # Abstract friends interface
    └── reactions/
        ├── reaction.dart               # Reaction model
        └── reaction_service.dart       # Abstract reaction interface
```

### Wave 2: social_core business logic + tests (~5 files)

```
packages/social_core/
├── lib/src/
│   ├── chat/chat_rules.dart            # MessageValidator, RateLimiter, SocialModeFilter
│   └── moderation/mute_calculator.dart # Threshold logic (50% of non-bot players)
└── test/
    ├── chat/chat_rules_test.dart
    ├── moderation/mute_calculator_test.dart
    └── friends/friendship_test.dart
```

### Wave 3: Flutter app — Supabase implementations (~6 files)

```
apps/flutter_app/lib/
├── core/services/
│   └── chat_service.dart               # UPGRADE — implement ChatRepository, add Realtime subscription
├── features/social/
│   ├── data/
│   │   ├── supabase_chat_repository.dart     # ChatRepository impl with Supabase Realtime
│   │   ├── supabase_friends_repository.dart  # FriendsRepository impl
│   │   ├── supabase_moderation_repository.dart # ModerationRepository impl
│   │   └── supabase_reaction_repository.dart # ReactionRepository impl
│   └── providers/
│       └── social_providers.dart             # Riverpod providers for all social services
```

### Wave 4: Flutter app — Friends feature (~4 files)

```
apps/flutter_app/lib/features/
├── friends/
│   ├── presentation/
│   │   └── friends_screen.dart         # UPGRADE — full friends list with activity status
│   ├── providers/
│   │   └── friends_providers.dart      # friendsListProvider, pendingRequestsProvider, friendActivityProvider
│   └── widgets/
│       └── friend_request_card.dart    # Accept/decline UI for pending requests
├── home/presentation/
│   └── home_screen.dart                # UPGRADE — add Friends Activity strip at top
```

### Wave 5: Flutter app — Chat + reactions wiring (~5 files)

```
apps/flutter_app/lib/features/
├── game/presentation/widgets/
│   ├── game_chat.dart                  # UPGRADE — wire to Supabase via provider, spectator chat separation
│   ├── emoji_bar.dart                  # UPGRADE — wire onEmojiTap to reaction repository
│   └── player_node.dart               # UPGRADE — wire FloatingChatBubble to incoming messages
├── social/
│   └── widgets/
│       ├── mute_vote_overlay.dart      # NEW — democratic mute UI (glass styled)
│       └── voice_status_indicator.dart # NEW — mic icon + status pill (uses stub for now)
```

### Wave 6: Flutter app — Notification preferences + blocking (~3 files)

```
apps/flutter_app/lib/features/
├── settings/
│   └── presentation/
│       └── notification_settings_screen.dart  # NEW — 9 toggle categories + quiet hours
├── social/
│   └── data/
│       └── supabase_block_repository.dart     # Block/unblock users
│   └── providers/
│       └── block_providers.dart               # blockedUsersProvider
```

### Wave 7: Tests (~4 files)

```
packages/social_core/test/
├── chat/chat_rules_test.dart           # Message validation, rate limiting, social mode filtering
├── moderation/mute_calculator_test.dart # Threshold calculation
└── friends/friendship_test.dart        # Model equality, status transitions

apps/flutter_app/test/widget/
└── social/
    ├── game_chat_test.dart             # Social mode visibility, message rendering
    └── friends_screen_test.dart        # Friends list rendering, activity strip
```

---

## Key design decisions

### 1. ChatMessage model consolidation

The current `game_chat.dart` has a simple local `ChatMessage` class. Replace it with the `social_core` version:

```dart
// packages/social_core/lib/src/chat/chat_message.dart
class ChatMessage extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String content;
  final MessageType type;       // text, emoji, system, reaction
  final ChatChannel channel;    // all, team, spectator
  final DateTime createdAt;
  final bool isDeleted;
  final bool isSpectatorChat;
  // ...
}
```

Update `game_chat.dart` to import from `social_core` instead of using its local model.

### 2. Social mode enforcement centralized in chat_rules.dart

```dart
// packages/social_core/lib/src/chat/chat_rules.dart
class SocialModeFilter {
  static bool canSendText(RoomSocialMode mode) => mode == RoomSocialMode.full || mode == RoomSocialMode.chatOnly;
  static bool canSendEmoji(RoomSocialMode mode) => mode != RoomSocialMode.silent;
  static bool canShowBubbles(RoomSocialMode mode) => mode == RoomSocialMode.full || mode == RoomSocialMode.chatOnly;
  static bool canUseVoice(RoomSocialMode mode) => mode == RoomSocialMode.full;
}
```

### 3. Floating chat bubble integration

Messages received via Realtime → check social mode → if bubbles allowed → dispatch to `FloatingChatBubble` on the sender's `PlayerNode`. Use a Riverpod `StreamProvider` for incoming messages and a `chatBubbleProvider` that maps sender → latest message.

### 4. Friends activity strip

Horizontal scroll on home screen (above game list). Each card uses existing `FriendActivityCard` widget. Data comes from `friendActivityProvider` which subscribes to Supabase Realtime presence on the `profiles` table's `current_activity` field.

### 5. Spectator chat separation

When building chat message list, filter by `is_spectator_chat`:
- If player: show only `is_spectator_chat = false` messages
- If spectator: show only `is_spectator_chat = true` messages
- When sending: set `is_spectator_chat` based on `isSpectatorProvider`

### 6. Abstract interfaces in social_core

All repository interfaces are abstract classes with no Supabase dependency:

```dart
abstract class ChatRepository {
  Stream<ChatMessage> messageStream(String roomId);
  Future<List<ChatMessage>> recentMessages(String roomId, {int limit = 100});
  Future<bool> sendMessage(String roomId, String content, {ChatChannel channel});
  Future<void> deleteMessage(String messageId);
}
```

Supabase implementations live in `features/social/data/` in the Flutter app.

---

## Social mode enforcement matrix (reference)

| Feature | Full | Chat Only | Silent | Focus |
|---------|------|-----------|--------|-------|
| Text chat | ✅ | ✅ | ❌ | ❌ |
| Voice chat | ✅ | ❌ | ❌ | ❌ |
| All emojis (6) | ✅ | ✅ | ❌ | ✅ (2 only) |
| Floating bubbles | ✅ | ✅ | ❌ | ❌ |
| Quick phrases | ✅ | ✅ | ❌ | ✅ (limited) |

---

## File structure summary

**~37 new/upgraded files:**

```
packages/social_core/lib/
├── social_core.dart                            # UPGRADE (barrel)
└── src/
    ├── chat/
    │   ├── chat_message.dart                   # NEW
    │   ├── chat_repository.dart                # NEW
    │   └── chat_rules.dart                     # NEW
    ├── voice/
    │   ├── voice_service.dart                  # NEW (abstract)
    │   ├── voice_state.dart                    # NEW
    │   └── stub_voice_service.dart             # NEW
    ├── moderation/
    │   ├── mute_vote.dart                      # NEW
    │   ├── moderation_repository.dart          # NEW
    │   ├── mute_calculator.dart                # NEW
    │   └── report.dart                         # NEW
    ├── friends/
    │   ├── friendship.dart                     # NEW
    │   ├── friend_activity.dart                # NEW
    │   └── friends_repository.dart             # NEW
    └── reactions/
        ├── reaction.dart                       # NEW
        └── reaction_service.dart               # NEW

packages/social_core/test/
├── chat/chat_rules_test.dart                   # NEW
├── moderation/mute_calculator_test.dart         # NEW
└── friends/friendship_test.dart                # NEW

apps/flutter_app/lib/
├── features/social/
│   ├── data/
│   │   ├── supabase_chat_repository.dart       # NEW
│   │   ├── supabase_friends_repository.dart    # NEW
│   │   ├── supabase_moderation_repository.dart # NEW
│   │   └── supabase_reaction_repository.dart   # NEW
│   ├── providers/
│   │   └── social_providers.dart               # NEW
│   └── widgets/
│       ├── mute_vote_overlay.dart              # NEW
│       └── voice_status_indicator.dart         # NEW
├── features/friends/
│   ├── presentation/friends_screen.dart        # UPGRADE
│   ├── providers/friends_providers.dart         # NEW
│   └── widgets/friend_request_card.dart        # NEW
├── features/home/presentation/home_screen.dart # UPGRADE (add activity strip)
├── features/game/presentation/widgets/
│   ├── game_chat.dart                          # UPGRADE (Supabase wiring, spectator chat)
│   ├── emoji_bar.dart                          # UPGRADE (reaction wiring)
│   └── player_node.dart                        # UPGRADE (bubble wiring)
├── features/settings/presentation/
│   └── notification_settings_screen.dart       # NEW
└── core/services/chat_service.dart             # UPGRADE

apps/flutter_app/test/widget/social/
├── game_chat_test.dart                         # NEW
└── friends_screen_test.dart                    # NEW
```

---

## Do NOT do these things

- Do NOT use `Color.withValues()` — use `withOpacity()` (Flutter 3.24)
- Do NOT add `livekit_client` dependency — use abstract interface + stub
- Do NOT add `supabase_flutter` to social_core's pubspec — keep it pure Dart
- Do NOT create duplicate widgets for things that already exist (see Critical fix #1)
- Do NOT modify any Session 8/9 files (glass widgets, animation files) — use them as-is
- Do NOT modify any Session 10 game screen files unless needed for chat/bubble wiring
- Do NOT use `DM Serif Display` font — Poppins + Inter only
- Do NOT replace the existing `gameStateProvider` signature
- Do NOT build full real-time multiplayer networking — wire to Supabase but use stubs where needed
- Do NOT restructure existing routing — add new routes alongside existing ones

---

## Testing guidance

After building:

```bash
# social_core package tests
cd packages/social_core && dart test

# App should analyze cleanly
cd apps/flutter_app && fvm flutter analyze

# App tests should still pass (target: 57/60 minimum, same as Session 10)
cd apps/flutter_app && fvm flutter test --timeout 60s
```

New tests to add:
- `social_core/test/chat/chat_rules_test.dart` — message validation (empty, too long, rate limited), social mode filtering
- `social_core/test/moderation/mute_calculator_test.dart` — threshold at 50%, edge cases (1 player, all vote, bots excluded)
- `social_core/test/friends/friendship_test.dart` — model equality, status transitions
- `apps/flutter_app/test/widget/social/game_chat_test.dart` — hidden in Silent/Focus, visible in Full/ChatOnly, spectator separation
- `apps/flutter_app/test/widget/social/friends_screen_test.dart` — renders friend list, activity status indicators

---

## Verification

```bash
# Static analysis
cd packages/social_core && dart analyze
cd apps/flutter_app && fvm flutter analyze

# social_core tests
cd packages/social_core && dart test

# All app tests (target: ≥57/60 — no regressions from Session 10)
cd apps/flutter_app && fvm flutter test --timeout 60s
```
