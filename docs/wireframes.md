# Game Platform — Screen Wireframes

> Canonical reference for all app screens. Screen IDs (SCR-XX) are stable identifiers for use in issues, PRs, and design discussions.
>
> These wireframes are derived from the Flutter source code in `apps/flutter_app/lib/`. No design tool files (.fig / .sketch) exist yet in the repository — this document is the single source of truth until they are added.

---

## Screen Index

| ID | Screen Name | Route | Group |
|----|-------------|-------|-------|
| SCR-01 | Splash | `/` | Auth |
| SCR-02 | Login | `/login` | Auth |
| SCR-03 | Register | `/register` | Auth |
| SCR-04 | Onboarding | `/onboarding` | Auth |
| SCR-05 | Home | `/home` | Main Shell |
| SCR-06 | Shop | `/shop` | Main Shell |
| SCR-07 | Leaderboard (Ranks) | `/leaderboard` | Main Shell |
| SCR-08 | Profile | `/profile` | Main Shell |
| SCR-09 | Lobby | `/lobby/:gameType` | Lobby Flow |
| SCR-10 | Join by Code | `/lobby/:gameType/join` | Lobby Flow |
| SCR-11 | Room / Waiting Room | `/room/:roomId` | Lobby Flow |
| SCR-12 | Game Screen (dispatcher) | `/game/:gameId` | Game |
| SCR-12a | Twenty-Nine Game | `/game/:gameId` (`type=twenty_nine`) | Game |
| SCR-12b | Oh Hell Game | `/game/:gameId` (`type=oh_hell`) | Game |
| SCR-12c | Hearts Game | `/game/:gameId` (`type=hearts`) | Game |
| SCR-12d | Spades Game | `/game/:gameId` (`type=spades`) | Game |
| SCR-12e | Bridge Game | `/game/:gameId` (`type=bridge`) | Game |
| SCR-12f | Chess Game | `/game/:gameId` (`type=chess`) | Game |
| SCR-12g | Ludo Game | `/game/:gameId` (`type=ludo`) | Game |
| SCR-12h | Sequence Game | `/game/:gameId` (`type=sequence`) | Game |
| SCR-13 | Settings | `/settings` | Settings |
| SCR-14 | Notification Settings | `/settings/notifications` | Settings |
| SCR-15 | Challenges | `/challenges` | Profile Features |
| SCR-16 | Season Pass | `/season-pass` | Profile Features |
| SCR-17 | Referral | `/referral` | Profile Features |
| SCR-18 | Friends | `/friends` | Social |
| SCR-19 | Messages | `/messages` | Social |
| SCR-20 | DM Thread | `/messages/:userId` | Social |
| SCR-21 | History | `/history` | History |
| SCR-22 | Replay | `/replay/:roomId` | History |
| SCR-23 | Subscription | `/subscription` | Commerce |
| SCR-24 | Tournaments | `/tournaments` | Tournaments |
| SCR-25 | Tournament Detail | `/tournament/:tournamentId` | Tournaments |

---

## Navigation Flow

```
[SCR-01 Splash]
    ├── logged in  ──▶ [SCR-05 Home]
    └── logged out ──▶ [SCR-02 Login]
                            ├── [SCR-03 Register] ──▶ [SCR-04 Onboarding] ──▶ [SCR-05 Home]
                            └── Guest sign-in ──▶ [SCR-05 Home]

[SCR-05 Home] (bottom nav)
    ├── tap game tile ──▶ [SCR-09 Lobby]
    │                         ├── Join by Code ──▶ [SCR-10 Join by Code]
    │                         └── tap room / Create ──▶ [SCR-11 Room]
    │                                                        └── Start ──▶ [SCR-12 Game]
    ├── history icon ──▶ [SCR-21 History] ──▶ [SCR-22 Replay]
    ├── messages icon ──▶ [SCR-19 Messages] ──▶ [SCR-20 DM Thread]
    ├── friends icon ──▶ [SCR-18 Friends]
    ├── Resume Game card ──▶ [SCR-11 Room] or [SCR-12 Game]
    ├── [SCR-06 Shop] (bottom nav tab)
    │       └── Subscription link ──▶ [SCR-23 Subscription]
    ├── [SCR-07 Leaderboard] (bottom nav tab)
    └── [SCR-08 Profile] (bottom nav tab)
            ├── ⚙️ icon ──▶ [SCR-13 Settings] ──▶ [SCR-14 Notification Settings]
            ├── Challenges ──▶ [SCR-15 Challenges]
            ├── Season Pass ──▶ [SCR-16 Season Pass]
            └── Referral ──▶ [SCR-17 Referral]
```

---

## Group 1 · Auth Flow

### SCR-01 · Splash Screen

**Route:** `/`  
**File:** `apps/flutter_app/lib/core/routing/app_router.dart` (`_SplashScreen`)  
**Description:** Auto-redirect. Sends logged-in users to Home, logged-out users to Login. No visible UI beyond a loading spinner.

```
┌──────────────────────────┐
│                          │
│                          │
│                          │
│           ◌             │
│        [spinner]         │
│                          │
│                          │
└──────────────────────────┘
```

---

### SCR-02 · Login Screen

**Route:** `/login`  
**File:** `apps/flutter_app/lib/features/auth/presentation/login_screen.dart`  
**Description:** Entry point for returning users. Offers email/password sign-in (collapsible form) and a "Play as Guest" option.

```
┌──────────────────────────┐
│                          │  ← Felt green background
│      [App Logo]          │
│     Game Platform        │
│                          │
│  ┌────────────────────┐  │
│  │  Email             │  │
│  └────────────────────┘  │
│  ┌────────────────────┐  │
│  │  Password          │  │
│  └────────────────────┘  │
│                          │
│  [      Sign In      ]   │
│                          │
│  [   Play as Guest   ]   │
│                          │
│  Don't have an account?  │
│  Register →              │
└──────────────────────────┘
```

---

### SCR-03 · Register Screen

**Route:** `/register`  
**File:** `apps/flutter_app/lib/features/auth/presentation/register_screen.dart`  
**Description:** New user sign-up with email and password.

```
┌──────────────────────────┐
│                          │
│      Create Account      │
│                          │
│  ┌────────────────────┐  │
│  │  Email             │  │
│  └────────────────────┘  │
│  ┌────────────────────┐  │
│  │  Password          │  │
│  └────────────────────┘  │
│  ┌────────────────────┐  │
│  │  Confirm Password  │  │
│  └────────────────────┘  │
│                          │
│  [      Register     ]   │
│                          │
│  Already have an account?│
│  Sign In →               │
└──────────────────────────┘
```

---

### SCR-04 · Onboarding Screen

**Route:** `/onboarding`  
**File:** `apps/flutter_app/lib/features/auth/presentation/onboarding_screen.dart`  
**Description:** Post-registration setup flow. Guides new users through picking a username and optionally an avatar.

```
┌──────────────────────────┐
│                          │
│        Welcome!          │
│                          │
│      ●  ○  ○             │  ← step indicator
│                          │
│   Pick a display name:   │
│  ┌────────────────────┐  │
│  │  Username          │  │
│  └────────────────────┘  │
│                          │
│  [       Next        ]   │
│                          │
└──────────────────────────┘
```

---

## Group 2 · Main Shell (Bottom Navigation)

All four screens below share a persistent bottom navigation bar.

```
Bottom Navigation Bar:
┌──────────────────────────────────────┐
│  🏠 Home  │  🛒 Shop  │  🏆 Ranks  │  👤 Profile  │
└──────────────────────────────────────┘
```

---

### SCR-05 · Home Screen

**Route:** `/home`  
**File:** `apps/flutter_app/lib/features/home/presentation/home_screen.dart`  
**Description:** Main landing screen. Contains: optional Resume Game card, friends activity strip, favourites & recently played, daily challenges, and the game selection grid.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ Choose a Game  💰 🕑 │ │  ← 💰=currency, 🕑=history, 💬=messages, 👥=friends
│ │                  💬 👥│ │
│ └──────────────────────┘ │
│                          │
│ ┌── Resume Game ───────┐ │  ← shown only when current_activity exists
│ │ ▶  Game in progress  │ │
│ │    Twenty-Nine       > │
│ └──────────────────────┘ │
│                          │
│ Friends ──────── See All │
│ ┌────┐ ┌────┐ ┌────┐    │  ← horizontal scroll
│ │ 👤 │ │ 👤 │ │ 👤 │    │
│ │Bob │ │Carol│ │Dave│    │
│ └────┘ └────┘ └────┘    │
│                          │
│ Favourites               │
│ ┌──────┐  ┌──────┐      │
│ │  29  │  │Hearts│      │
│ └──────┘  └──────┘      │
│                          │
│ Daily Challenges ── 12h  │
│ ┌──────────┐┌──────────┐ │  ← horizontal scroll
│ │Win 3 gms ││Play 5 rds│ │
│ │  0/3     ││   0/5    │ │
│ │  🪙 50   ││🪙30 💎5  │ │
│ └──────────┘└──────────┘ │
│                          │
│ Games                    │
│ ┌──────────┐┌──────────┐ │
│ │Twenty-Nine││ Oh Hell │ │
│ │ 4 players ││3-7 plyr │ │
│ ├──────────┤├──────────┤ │
│ │  Hearts  ││  Spades  │ │
│ │ 4 players ││4 players│ │
│ ├──────────┤├──────────┤ │
│ │  Bridge  ││   Ludo   │ │
│ │ 4 players ││2-4 plyr │ │
│ ├──────────┤├──────────┤ │
│ │ Sequence ││          │ │
│ │ 2-4 plyr ││          │ │
│ └──────────┘└──────────┘ │
│                          │
│ [Home][Shop][Ranks][Prfl]│
└──────────────────────────┘
```

---

### SCR-06 · Shop Screen

**Route:** `/shop`  
**File:** `apps/flutter_app/lib/features/shop/presentation/shop_screen.dart`  
**Description:** In-app store with three tabs: Skins (card & room themes), Gems (currency packs), and Featured. Currency shown in app bar.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ Shop            💰 💎│ │
│ └──────────────────────┘ │
│                          │
│ ⚠ Purchases not yet wired│
│                          │
│ [Skins] [Gems] [Featured]│  ← tab bar
│ ─────────────────────── │
│                          │
│ Card Skins               │
│ ┌──────┐  ┌──────┐      │
│ │Skin 1│  │Skin 2│      │
│ │[Buy] │  │[Buy] │      │
│ └──────┘  └──────┘      │
│                          │
│ Gem Packs                │
│ ┌──────────────────────┐ │
│ │  💎 100          $0.99│ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │  💎 500          $3.99│ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │  💎 1200         $8.99│ │
│ └──────────────────────┘ │
│                          │
│ [Home][Shop][Ranks][Prfl]│
└──────────────────────────┘
```

---

### SCR-07 · Leaderboard Screen

**Route:** `/leaderboard`  
**File:** `apps/flutter_app/lib/features/leaderboard/presentation/leaderboard_screen.dart`  
**Description:** Global rankings filterable by game. Under construction — placeholder data shown.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ Leaderboard           │ │
│ └──────────────────────┘ │
│                          │
│ ⚠ Placeholder data       │
│                          │
│ [All][29][Oh Hell]       │  ← horizontal filter chips
│ [Hearts][Chess][Ludo]    │
│                          │
│ ┌──────────────────────┐ │
│ │ 🥇  PlayerA    1,200 │ │
│ │ 🥈  PlayerB      980 │ │
│ │ 🥉  PlayerC      870 │ │
│ │     PlayerD      760 │ │
│ │     PlayerE      650 │ │
│ │     …                │ │
│ └──────────────────────┘ │
│                          │
│ [Home][Shop][Ranks][Prfl]│
└──────────────────────────┘
```

---

### SCR-08 · Profile Screen

**Route:** `/profile`  
**File:** `apps/flutter_app/lib/features/profile/presentation/profile_screen.dart`  
**Description:** User profile with avatar, level, XP bar, currency display, game statistics, subscription tier, and quick-links to challenge/season-pass/referral screens.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ Profile           ⚙️ │ │  ← ⚙️ goes to SCR-13 Settings
│ └──────────────────────┘ │
│                          │
│ ⚠ Profile under construct│
│                          │
│ ┌──────────────────────┐ │
│ │         👤           │ │
│ │     Guest Player     │ │
│ │      [Level 1]       │ │
│ │  0/100 XP            │ │
│ │  ████░░░░░░░░░░░░░░  │ │
│ │  Next: Level 2       │ │
│ │                      │ │
│ │   💰 200   💎 0      │ │
│ └──────────────────────┘ │
│                          │
│ ┌─ Subscription ───────┐ │
│ │  Free Tier  [Upgrade] │ │
│ └──────────────────────┘ │
│                          │
│ ┌─ Statistics ─────────┐ │
│ │ Games Played       0  │ │
│ │ Win Rate           0% │ │
│ │ Best Streak        0  │ │
│ │ Total Coins Earned 0  │ │
│ └──────────────────────┘ │
│                          │
│ ┌──────────────────────┐ │
│ │ 🏆 Challenges        >│ │
│ │ 🎖  Season Pass      >│ │
│ │ 🎁 Referral Program  >│ │
│ └──────────────────────┘ │
│                          │
│ [Home][Shop][Ranks][Prfl]│
└──────────────────────────┘
```

---

## Group 3 · Lobby Flow

### SCR-09 · Lobby Screen

**Route:** `/lobby/:gameType`  
**File:** `apps/flutter_app/lib/features/lobby/screens/lobby_screen.dart`  
**Description:** Per-game lobby listing all open rooms. Players can create a new room, join by a private code, or select an existing open room. A banner ad is shown at the bottom.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Twenty-Nine Lobby   │ │  ← game name varies
│ └──────────────────────┘ │
│                          │
│ [  🔑  Join by Code   ]  │  ← goes to SCR-10
│                          │
│ [  +   Create Room    ]  │  ← creates room, goes to SCR-11
│                          │
│ Open Rooms               │
│ ┌──────────────────────┐ │
│ │ Room A3F2    2/4  ▶  │ │
│ │ Room B7K1    3/4  ▶  │ │
│ │ Room C2D9    1/4  ▶  │ │
│ └──────────────────────┘ │
│                          │
│ ┌──── Banner Ad ───────┐ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

---

### SCR-10 · Join by Code Screen

**Route:** `/lobby/:gameType/join`  
**File:** `apps/flutter_app/lib/features/lobby/presentation/join_by_code_screen.dart`  
**Description:** Enter a 6-character room code to join a private room directly.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Join by Code        │ │
│ └──────────────────────┘ │
│                          │
│   Enter Room Code        │
│                          │
│  ┌──────────────────────┐│
│  │  A 3 F 2 _ _         ││
│  └──────────────────────┘│
│                          │
│  [       Join Room    ]  │
│                          │
└──────────────────────────┘
```

---

### SCR-11 · Room / Waiting Room Screen

**Route:** `/room/:roomId`  
**File:** `apps/flutter_app/lib/features/lobby/presentation/room_screen.dart`  
**Description:** Pre-game waiting room. Shows player seats with ready/not-ready status. Host controls: add bot, kick player, start game. All players can share the room code.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Room   Code: A3F2 📋│ │  ← 📋 copies code; share button also available
│ └──────────────────────┘ │
│                          │
│ Players (3/4)            │
│ ┌──────────────────────┐ │
│ │ 👤 PlayerA  HOST  ✓  │ │
│ │ 👤 PlayerB        ✓  │ │
│ │ 🤖 Bot 1          ✓  │ │
│ │ ── Empty Slot ──  ─  │ │
│ └──────────────────────┘ │
│                          │
│ [HOST] [  + Add Bot   ]  │  ← host only
│        [  📤 Share    ]  │
│                          │
│ [  ✓  Ready / Unready ]  │  ← all players
│                          │
│ [HOST] [  ▶  Start    ]  │  ← enabled when min players ready
│         (need ≥4 for 29) │
└──────────────────────────┘
```

---

## Group 4 · Game Screen

### SCR-12 · Game Screen (Dispatcher)

**Route:** `/game/:gameId`  
**File:** `apps/flutter_app/lib/features/game/screens/game_screen.dart`  
**Description:** Container shell that reads the room's `game_type` and delegates rendering to the appropriate game-specific sub-screen. Handles loading, 15-second timeout, and error states. All game variants share this single route.

**Sub-screen dispatch table:**

| Sub-ID | Game Type | File |
|--------|-----------|------|
| SCR-12a | `twenty_nine` | `game/presentation/screens/twenty_nine_game_screen.dart` |
| SCR-12b | `oh_hell` | `game/presentation/screens/oh_hell_game_screen.dart` |
| SCR-12c | `hearts` | `game/presentation/screens/hearts_game_screen.dart` |
| SCR-12d | `spades` | `game/presentation/screens/spades_game_screen.dart` |
| SCR-12e | `bridge` | `game/presentation/screens/bridge_game_screen.dart` |
| SCR-12f | `chess` | `game/presentation/screens/chess_game_screen.dart` |
| SCR-12g | `ludo` | `game/presentation/screens/ludo_game_screen.dart` |
| SCR-12h | `sequence` | `game/presentation/screens/sequence_game_screen.dart` |

---

### SCR-12a–d · Card Game Layout (Twenty-Nine / Oh Hell / Hearts / Spades)

**Description:** Standard 4-seat trick-taking layout. Shared structure across these games with minor per-game overlays (trump reveal, score cards, bidding).

```
┌──────────────────────────┐
│ Score: TeamA 42 / TeamB 38│  ← HUD score bar
│ ─────────────────────────│
│                          │
│        👤 North          │  ← opponent
│        🂠 🂠 🂠 🂠         │
│                          │
│  👤 West    [trick zone]  👤 East│
│             🂠 🂠 🂠 🂠           │
│                          │
│  💬  😊  😤   Trump: ♠   │  ← emoji bar + trump indicator
│                          │
│   🂡 🂢 🂣 🂤 🂥 🂦 🂧 🂨      │  ← your hand
│         [Sort] [✓ Ready] │
│ ─────────────────────────│
│  Ready chips    ⏱ 0:15  │  ← between-rounds state
└──────────────────────────┘

Overlays (appear contextually):
┌─ Round End ──────────────┐   ┌─ Game Over ──────────────┐
│ Round 3 complete         │   │ 🏆  You Won!             │
│ Team A: 82  Team B: 56   │   │ Final: A 162  B 134      │
│ [Continue →]             │   │ [Play Again] [Home]      │
└──────────────────────────┘   └──────────────────────────┘
```

---

### SCR-12b · Oh Hell Extra — Bidding + Score Card

**Description:** Oh Hell adds a bidding phase before each round and a running scorecard table.

```
┌─ Bidding Modal ──────────┐
│ How many tricks will     │
│ you win this round?      │
│  [0] [1] [2] [3] [4]    │
└──────────────────────────┘

┌─ Oh Hell Scorecard ──────┐
│ Rnd │ Alice │ Bob │ ...  │
│  1  │  2/2  │ 0/1 │ ...  │
│  2  │  1/3  │ 2/2 │ ...  │
└──────────────────────────┘
```

---

### SCR-12e · Bridge Game Layout

**Description:** Bridge adds auction/bidding box, dummy hand visibility, contract banner, and vulnerability indicator on top of the card game layout.

```
┌──────────────────────────┐
│ Contract: 4♠ by S  Vul:NS│  ← contract banner + vulnerability
│ ─────────────────────────│
│                          │
│       👤 North (Dummy)   │
│  [visible dummy hand]    │  ← dummy cards face-up after opening lead
│                          │
│  👤 West         👤 East │
│                          │
│       [trick zone]       │
│                          │
│  ┌── Bidding Box ──────┐ │  ← shown during auction phase
│  │ 1♣ 1♦ 1♥ 1♠ 1NT   │ │
│  │ 2♣ 2♦ …    Pass Dbl│ │
│  └────────────────────┘ │
│                          │
│  🂡 🂢 🂣 🂤 🂥 🂦 🂧 🂨      │
└──────────────────────────┘
```

---

### SCR-12f · Chess Game Layout

**Description:** 2-player chess on an 8×8 board. Turn timer shown. Chess is currently hidden from the Home screen grid pending a create-room form (M4).

```
┌──────────────────────────┐
│  ♟ Opponent      ⏱ 4:52 │
│ ─────────────────────────│
│  ┌──────────────────────┐│
│  │ r n b q k b n r     ││
│  │ p p p p p p p p     ││
│  │ . . . . . . . .     ││
│  │ . . . . . . . .     ││
│  │ . . . . . . . .     ││
│  │ . . . . P . . .     ││
│  │ P P P P . P P P     ││
│  │ R N B Q K B N R     ││
│  └──────────────────────┘│
│ ─────────────────────────│
│  ♙ You           ⏱ 5:12 │
└──────────────────────────┘
```

---

### SCR-12g · Ludo Game Layout

**Description:** 2–4 player Ludo on a 15×15 cross-shaped board. Players roll dice and move tokens.

```
┌──────────────────────────┐
│ [P1: Blue]   [P2: Red]   │
│ ┌──────────────────────┐ │
│ │                      │ │
│ │   [Blue Home]        │ │
│ │       [Ludo Board]   │ │
│ │               [Red]  │ │
│ │   [Green]  [Yellow]  │ │
│ │                      │ │
│ └──────────────────────┘ │
│ [P3: Green]  [P4: Yellow]│
│                          │
│  [  🎲  Roll Dice  ]     │
└──────────────────────────┘
```

---

### SCR-12h · Sequence Game Layout

**Description:** 2–4 player Sequence on a 10×10 board. Players play cards from their hand to claim board positions and form sequences of 5.

```
┌──────────────────────────┐
│ Your turn   [Sequences:0]│
│ ┌──────────────────────┐ │
│ │  J ♠2 ♣3 ♣4 ♥5 ♠6  │ │
│ │  ♦7 ♦8 ♣9 ♣T  J ♠Q │ │
│ │  …  (10×10 grid)    │ │
│ └──────────────────────┘ │
│                          │
│  Your hand:              │
│  🂡 🂢 🂣 🂤 🂥             │
│  [  Play Card  ]         │
└──────────────────────────┘
```

---

## Group 5 · Settings

### SCR-13 · Settings Screen

**Route:** `/settings`  
**File:** `apps/flutter_app/lib/features/profile/presentation/settings_screen.dart`  
**Description:** App settings accessible from the Profile screen toolbar. Sections: Account, Audio, Notifications, App info.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Settings            │ │
│ └──────────────────────┘ │
│                          │
│ ┌─ Account ────────────┐ │
│ │ user@example.com     │ │
│ │ [    Sign Out    ]   │ │
│ └──────────────────────┘ │
│                          │
│ ┌─ Audio ──────────────┐ │
│ │ Sound Effects [ON ●] │ │
│ │ Music         [ON ●] │ │
│ └──────────────────────┘ │
│                          │
│ ┌─ Notifications ──────┐ │
│ │ Notification Settings>│ │  ← goes to SCR-14
│ └──────────────────────┘ │
│                          │
│ ┌─ App ────────────────┐ │
│ │ Check for Update   > │ │
│ │ Version 1.0.0        │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

---

### SCR-14 · Notification Settings Screen

**Route:** `/settings/notifications`  
**File:** `apps/flutter_app/lib/features/social/presentation/notification_settings_screen.dart`  
**Description:** Per-event push notification toggles.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Notifications       │ │
│ └──────────────────────┘ │
│                          │
│ ┌──────────────────────┐ │
│ │ Game Invites  [ON ●] │ │
│ │ Friend Req.   [ON ●] │ │
│ │ Turn Reminder [ON ●] │ │
│ │ Messages      [ON ●] │ │
│ │ Promotions    [OFF○] │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

---

## Group 6 · Profile Features

### SCR-15 · Challenges Screen

**Route:** `/challenges`  
**File:** `apps/flutter_app/lib/features/challenges/presentation/challenges_screen.dart`  
**Description:** Daily and weekly challenges with progress bars and coin/gem rewards.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Challenges          │ │
│ └──────────────────────┘ │
│                          │
│ Daily  ─────── Resets 8h │
│ ┌──────────────────────┐ │
│ │ Win 3 games          │ │
│ │ ████░░░░░  2/3       │ │
│ │ Reward: 🪙 50        │ │
│ ├──────────────────────┤ │
│ │ Play 5 rounds        │ │
│ │ ██░░░░░░░  1/5       │ │
│ │ Reward: 🪙 30 + 💎 5 │ │
│ ├──────────────────────┤ │
│ │ Score 100 points     │ │
│ │ ░░░░░░░░░  0/100     │ │
│ │ Reward: 🪙 40        │ │
│ └──────────────────────┘ │
│                          │
│ Weekly                   │
│ ┌──────────────────────┐ │
│ │ Win 10 games  0/10   │ │
│ │ Reward: 💎 25        │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

---

### SCR-16 · Season Pass Screen

**Route:** `/season-pass`  
**File:** `apps/flutter_app/lib/features/season_pass/presentation/season_pass_screen.dart`  
**Description:** Battle-pass style tiered reward track. Free and premium tracks shown with per-level rewards. Upgrade CTA at the bottom.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Season Pass         │ │
│ └──────────────────────┘ │
│                          │
│  Season 1                │
│  ████████░░░░  Level 8   │
│                          │
│ Lvl  Free Track  Premium │
│ ┌────┬──────────┬───────┐│
│ │  1 │  🪙 50  │ 💎 10 ││
│ │  2 │          │ 🎨Skin││
│ │  3 │  🪙 100 │ 💎 25 ││
│ │  4 │          │ 🎨Skin││
│ │ …  │  …      │ …     ││
│ └────┴──────────┴───────┘│
│                          │
│ [ Upgrade to Premium ]   │
└──────────────────────────┘
```

---

### SCR-17 · Referral Screen

**Route:** `/referral`  
**File:** `apps/flutter_app/lib/features/referral/presentation/referral_screen.dart`  
**Description:** Invite friends via a unique referral code. Earn coins per successful referral.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Referral Program    │ │
│ └──────────────────────┘ │
│                          │
│  Invite friends &        │
│  earn rewards!           │
│                          │
│  Your Code:              │
│ ┌──────────────────────┐ │
│ │ PLAY-XYZABC   [Copy] │ │
│ └──────────────────────┘ │
│                          │
│ [    Share Invite Link ]  │
│                          │
│  Referrals made: 0       │
│  Reward: 🪙 100/signup   │
└──────────────────────────┘
```

---

## Group 7 · Social

### SCR-18 · Friends Screen

**Route:** `/friends`  
**File:** `apps/flutter_app/lib/features/friends/presentation/friends_screen.dart`  
**Description:** Friend list showing online/in-game/offline status, pending requests, and a search field to add new friends.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Friends       + Add │ │
│ └──────────────────────┘ │
│                          │
│ Pending (1)              │
│ ┌──────────────────────┐ │
│ │ 👤 Alice  [✓] [✗]   │ │  ← accept / decline
│ └──────────────────────┘ │
│                          │
│ ┌── Search ────────────┐ │
│ │  🔍 Find friends…    │ │
│ └──────────────────────┘ │
│                          │
│ Friends (5)              │
│ ┌──────────────────────┐ │
│ │ 👤 Bob   🟢 In Game  │ │
│ │ 👤 Carol  🔵 Online  │ │
│ │ 👤 Dave   ⚪ Offline │ │
│ │ 👤 Eve    ⚪ Offline │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

---

### SCR-19 · Messages Screen

**Route:** `/messages`  
**File:** `apps/flutter_app/lib/features/social/presentation/messages_screen.dart`  
**Description:** Direct message inbox listing all conversations sorted by recency.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Messages            │ │
│ └──────────────────────┘ │
│                          │
│ ┌──────────────────────┐ │
│ │ 👤 Alice   "gg!"  2m │ │
│ │ 👤 Bob   "rematch?" 1h│ │
│ │ 👤 Carol    "hi"   2h │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

---

### SCR-20 · DM Thread Screen

**Route:** `/messages/:userId`  
**File:** `apps/flutter_app/lib/features/social/presentation/dm_thread_screen.dart`  
**Description:** 1-on-1 chat with a friend. Scrollable message history and text input.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Alice               │ │
│ └──────────────────────┘ │
│                          │
│          "gg that game!" │  ← received (right-aligned)
│  "Yeah great round :)"   │  ← sent (left-aligned)
│          "Rematch?"      │
│                          │
│ ┌────────────────────┬──┐│
│ │  Type a message…   │ ▶ ││
│ └────────────────────┴──┘│
└──────────────────────────┘
```

---

## Group 8 · History

### SCR-21 · History Screen

**Route:** `/history`  
**File:** `apps/flutter_app/lib/features/history/presentation/history_screen.dart`  
**Description:** List of completed games for the current user. Tap a row to view the replay.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← History             │ │
│ └──────────────────────┘ │
│                          │
│ ┌──────────────────────┐ │
│ │ Twenty-Nine    Won  >│ │
│ │ Jun 20  ·  Score: 82 │ │
│ ├──────────────────────┤ │
│ │ Hearts        Lost  >│ │
│ │ Jun 19  ·  Score: 31 │ │
│ ├──────────────────────┤ │
│ │ Oh Hell        Won  >│ │
│ │ Jun 18  ·  Score: 56 │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

---

### SCR-22 · Replay Screen

**Route:** `/replay/:roomId`  
**File:** `apps/flutter_app/lib/features/history/presentation/replay_screen.dart`  
**Description:** Step-through playback of a completed game. Mirrors the game screen layout with playback controls at the bottom.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Replay              │ │
│ └──────────────────────┘ │
│                          │
│  [Game table — frozen]   │
│  (same layout as SCR-12) │
│                          │
│                          │
│                          │
│ ┌──────────────────────┐ │
│ │ |◀  ◀   ▶   ▶|      │ │  ← step back/forward, skip
│ │    Move 14 / 48      │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

---

## Group 9 · Commerce

### SCR-23 · Subscription Screen

**Route:** `/subscription`  
**File:** `apps/flutter_app/lib/features/shop/presentation/subscription_screen.dart`  
**Description:** Premium subscription offer. Compares Free vs Premium tiers and shows upgrade pricing.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Subscription        │ │
│ └──────────────────────┘ │
│                          │
│ ┌─────────┬─────────────┐│
│ │  Free   │   Premium   ││
│ ├─────────┼─────────────┤│
│ │ Ads     │  No Ads     ││
│ │ 2 Skins │  All Skins  ││
│ │ 1× XP   │  2× XP     ││
│ │ –       │  Priority Q ││
│ └─────────┴─────────────┘│
│                          │
│ [ Upgrade — $4.99/month ]│
│                          │
│     Restore Purchases    │
└──────────────────────────┘
```

---

## Group 10 · Tournaments

### SCR-24 · Tournaments Screen

**Route:** `/tournaments`  
**File:** `apps/flutter_app/lib/features/tournaments/presentation/screens/tournaments_screen.dart`  
**Description:** Lists active, upcoming, and past tournaments. Filter by game type. Tap to view tournament detail.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Tournaments         │ │
│ └──────────────────────┘ │
│                          │
│ [Active] [Upcoming] [Past]│  ← tabs
│                          │
│ ┌──────────────────────┐ │
│ │ 🏆 Monthly 29 Cup    │ │
│ │ 32 players · Starts 1h│ │
│ │ Prize: 💎 500   [Join]│ │
│ ├──────────────────────┤ │
│ │ 🏆 Hearts Weekly     │ │
│ │ 16 players · Ongoing │ │
│ │ Prize: 💎 200  [View] │ │
│ └──────────────────────┘ │
└──────────────────────────┘
```

---

### SCR-25 · Tournament Detail Screen

**Route:** `/tournament/:tournamentId`  
**File:** `apps/flutter_app/lib/features/tournaments/presentation/screens/tournament_detail_screen.dart`  
**Description:** Full bracket and standings for a single tournament. Shows rounds, match pairings, and current participant positions.

```
┌──────────────────────────┐
│ ┌──── GlassAppBar ─────┐ │
│ │ ← Monthly 29 Cup      │ │
│ └──────────────────────┘ │
│                          │
│  Status: Ongoing         │
│  Prize: 💎 500           │
│  Players: 32             │
│                          │
│ [Bracket] [Standings]    │  ← tabs
│                          │
│  Quarter Finals          │
│ ┌──────────────────────┐ │
│ │ PlayerA  vs  PlayerB>│ │
│ │ PlayerC  vs  PlayerD>│ │
│ │ PlayerE  vs  PlayerF>│ │
│ │ PlayerG  vs  PlayerH>│ │
│ └──────────────────────┘ │
│                          │
│ [  Register / View  ]    │
└──────────────────────────┘
```

---

*Generated from source code — `apps/flutter_app/lib/core/routing/routes.dart` and feature screen files. Update this document when new screens are added.*
