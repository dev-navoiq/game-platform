# Session 13 — Assets & Skins System

## Load these files first

```
prompts/_context.md
prompts/14-assets-skins-system.md
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
**Session 8 ✅** — Glass UI component library. 58/60 tests pass.
**Session 9 ✅** — Animation system: 20 files in `lib/shared/animations/`. 58/60 tests pass.
**Session 10 ✅** — Game screens: 34 files (foundation, widgets, 8 game screens). 57/60 tests pass.
**Session 11 ✅** — Social features: `social_core` package (56 tests), Supabase repos, friends, chat/emoji wiring. 67/70 tests pass.
**Session 12 ✅** — UI Polish + Monetization: `packages/monetization/` (69 tests), glass UI on all screens, ad widgets, 18 monetization providers. 67/71 tests pass (4 pre-existing).

### Current state of assets & skins infrastructure

**Asset directories already exist** (`apps/flutter_app/assets/`):
```
assets/
├── cards/classic/         # .gitkeep only — no actual images
├── cards/modern/          # .gitkeep only
├── cards/minimal/         # .gitkeep only
├── cards/neon/            # .gitkeep only
├── rooms/classic/         # .gitkeep only
├── rooms/casino/          # .gitkeep only
├── rooms/nature/          # .gitkeep only
├── rooms/space/           # .gitkeep only
├── boards/{chess,ludo,sequence}/  # .gitkeep only
├── audio/{common,chess,twenty_nine,hearts,oh_hell,ludo}/  # .gitkeep only
├── animations/            # .gitkeep only
├── fonts/Poppins-*.ttf    # Already working
└── icons/                 # .gitkeep only
```

**pubspec.yaml** already declares all asset directories.

**Database schema** already has:
```sql
create type skin_type as enum ('card_deck', 'room_background', 'avatar_frame', 'emote_pack');

create table skins (
  id, name, skin_type, price_coins, price_gems, preview_url,
  asset_key text not null,  -- e.g., 'cards/modern'
  is_premium, is_default, metadata jsonb, created_at
);

create table user_skins (
  id, user_id, skin_id, is_equipped, acquired_at,
  unique (user_id, skin_id)
);
```

Seeded skins: 4 card decks (classic/modern/minimal/neon), 4 room backgrounds (classic/casino/nature/space), 1 avatar frame (gold).

### Existing skin-related code

**Monetization package** (`packages/monetization/`):
- `lib/src/models/skin.dart` — `SkinType` enum (cardBack/cardFace/roomTheme/avatar), `Skin` class (Equatable, `isFree` getter), `UserSkin` class
- `lib/src/services/skin_service.dart` — `SkinRepository` interface + `SkinService` (purchase with coins/gems preference, equip with auto-unequip same type)

**Flutter app**:
- `core/di/providers.dart` — `selectedCardSkinProvider = StateProvider<String>((ref) => 'default')`, `selectedRoomSkinProvider = StateProvider<String>((ref) => 'default')`
- `core/config/constants.dart` — `keyCardSkin = 'card_skin'`, `keyRoomSkin = 'room_skin'`
- `core/di/monetization_providers.dart` — `skinRepositoryProvider`, `skinServiceProvider`
- `features/shop/data/supabase_skin_repository.dart` — Stub, all methods throw `UnimplementedError`
- `features/shop/presentation/widgets/skin_preview_card.dart` — Glass card with icon placeholder, price display, equip/buy buttons
- `features/shop/presentation/shop_screen.dart` — 3 tabs (Gem Packs, Card Skins, Room Themes) with hardcoded placeholder data

**PlayingCardWidget** (`lib/shared/widgets/playing_card_widget.dart`):
- Has `skinId` parameter but **completely ignores it**
- Renders everything programmatically with Unicode suit symbols (♥♦♣♠)
- Card back is hardcoded blue gradient
- **This needs to be upgraded** to load skin-specific assets

**CardHand** (`lib/features/game/presentation/widgets/card_hand.dart`):
- Uses `PlayingCardWidget` but does **not** pass `skinId`
- Has helper functions `rankToDisplay()` and `suitToString()`

---

## Critical fix #1: Do NOT use image assets — use programmatic rendering

The prompt 14 spec assumes PNG image files for every card face (52 × N skins). **We are NOT shipping hundreds of PNG files.** Instead:

1. **Card skins = colour themes + back design**, NOT separate face PNGs
2. Keep the existing programmatic card face rendering (Unicode symbols)
3. Each card skin defines: `cardColor` (red suit), `cardBlackColor` (black suit), `backgroundColor`, `borderColor`, and a **card back widget** (gradient/pattern)
4. Room skins define: `feltColor`, `feltDarkColor`, `accentColor`, and optionally a background pattern widget

This keeps the app small and avoids managing hundreds of image assets.

---

## Critical fix #2: Flutter version compatibility

Flutter 3.24.0 is in use:
- **`Color.withValues()` is NOT available** — use `withOpacity()` instead
- Use **Poppins** + **Inter** via `google_fonts`

---

## Critical fix #3: Colour alignment

Use the existing project palette:

| Generic | Replace with |
|---------|-------------|
| `Colors.amber` | `AppColors.accent` (#C47B2B) |
| `Colors.green` | `AppColors.success` (#27ae60) |
| `Colors.red` | `AppColors.danger` (#e74c3c) |
| `Colors.grey.shade800` | `AppColors.textMuted` |
| Glass surfaces | Via `GlassContainer`/`GlassCard` |

---

## Critical fix #4: SkinType enum mismatch

The DB uses `skin_type` enum: `card_deck`, `room_background`, `avatar_frame`, `emote_pack`.
The monetization package has `SkinType`: `cardBack`, `cardFace`, `roomTheme`, `avatar`.

**These don't match.** When building the asset system, align to the DB values. The `SkinType` in monetization is already published, so keep it but map between them in the repository layer.

---

## What to build

### Wave 1: Card & Room Skin Theme Definitions (~3 files)

Define skin themes as code (no image assets needed):

```
apps/flutter_app/lib/core/assets/
├── card_skin_theme.dart         # CardSkinTheme class + 4 static presets
├── room_skin_theme.dart         # RoomSkinTheme class + 4 static presets
└── asset_registry.dart          # Central registry mapping skinId → theme
```

**CardSkinTheme** should define:
- `id`, `displayName`
- `redSuitColor`, `blackSuitColor` (for rank/suit text)
- `cardFaceColor` (card background)
- `cardBorderColor`
- `cardBackGradient` (LinearGradient for card back)
- `cardBackPattern` (optional CustomPainter for pattern overlay on back)

**4 presets:**
- **Classic**: white face, red/black suits, blue gradient back
- **Modern**: light grey face, crimson/navy suits, dark gradient back
- **Neon**: dark (#1a1a2e) face, neon pink/cyan suits, neon gradient back with glow
- **Gold**: cream (#faf3e0) face, burgundy/dark brown suits, gold gradient back

**RoomSkinTheme** should define:
- `id`, `displayName`
- `feltColor`, `feltDarkColor` (for FeltBackground gradient)
- `accentColor` (for buttons, highlights)
- `glassOpacity` (adjust glass surface for different backgrounds)

**4 presets:**
- **Classic**: current felt green (#1e5631 → #122e1d), gold accent
- **Casino**: deep red (#5c1a1a → #2d0f0f), gold accent
- **Nature**: forest (#2d5a1e → #1a3a10), emerald accent
- **Space**: deep blue (#0a1628 → #050d1a), cyan accent

**AssetRegistry**: singleton that maps `skinId` string → `CardSkinTheme` / `RoomSkinTheme`. Provides `getCardSkin(String id)`, `getRoomSkin(String id)`, `allCardSkins`, `allRoomSkins`.

### Wave 2: Upgrade PlayingCardWidget for skin support (~1 file)

**Modify**: `lib/shared/widgets/playing_card_widget.dart`

- Accept `CardSkinTheme? theme` parameter (optional, defaults to Classic)
- Use theme colours for:
  - Card face background (`cardFaceColor`)
  - Suit/rank text colour (`redSuitColor` or `blackSuitColor`)
  - Border (`cardBorderColor`)
  - Card back (replace hardcoded gradient with `cardBackGradient` + optional `cardBackPattern`)
- Keep existing programmatic rendering (Unicode symbols) — do NOT switch to images
- Keep backward compatibility: existing callers that don't pass `theme` still work

### Wave 3: Upgrade FeltBackground for room skins (~1 file)

**Modify**: `lib/shared/widgets/felt_background.dart`

- Accept optional `RoomSkinTheme? theme` parameter
- Use theme's `feltColor` / `feltDarkColor` for the radial gradient (fallback to current colors)
- Keep `showAmbientGlow` parameter working

### Wave 4: Wire skins into game screens (~3 files)

**Modify**: `lib/features/game/presentation/widgets/card_hand.dart`
- Read `selectedCardSkinProvider` → look up `CardSkinTheme` from `AssetRegistry` → pass to `PlayingCardWidget`

**Modify**: Game table / game screens that use `FeltBackground`
- Read `selectedRoomSkinProvider` → look up `RoomSkinTheme` from `AssetRegistry` → pass to `FeltBackground`

**New provider**: `lib/core/di/skin_theme_providers.dart`
- `cardSkinThemeProvider` — reads `selectedCardSkinProvider`, returns `CardSkinTheme` via `AssetRegistry`
- `roomSkinThemeProvider` — reads `selectedRoomSkinProvider`, returns `RoomSkinTheme` via `AssetRegistry`

### Wave 5: Skin Selector Widget (~1 file)

**New**: `lib/shared/widgets/skins/skin_selector.dart`

- Glass-styled grid of skin options
- Shows mini card preview (small PlayingCardWidget with the theme applied) for card skins
- Shows colour swatch for room skins
- Selected skin has gold border + checkmark
- Locked skins show lock icon + price
- Premium badge for non-free skins

### Wave 6: Wire into Shop Screen (~1 file)

**Modify**: `lib/features/shop/presentation/shop_screen.dart`

- Replace hardcoded card/room skin lists with data from `AssetRegistry`
- Card Skins tab: use `SkinSelector` or `SkinPreviewCard` with live card preview
- Room Themes tab: same with colour swatches
- Wire purchase flow to `SkinService` (via monetization providers)
- Wire equip flow to update `selectedCardSkinProvider` / `selectedRoomSkinProvider`

### Wave 7: Audio Asset Manager (~2 files)

**New**: `lib/core/assets/audio_manager.dart`
- Defines all audio asset paths as constants (card_deal, card_play, shuffle, win, lose, etc.)
- Preload method for game-specific sounds
- Integration point for `AudioService` (existing in `core/services/`)

**New**: `lib/core/assets/audio_assets.dart`
- Static const path definitions organized by category (common, twenty_nine, chess, etc.)
- Matches the `assets/audio/` directory structure

### Wave 8: Settings Screen — Skin Selection (~1 file)

**Modify**: `lib/features/settings/presentation/settings_screen.dart`
- Add "Card Skin" and "Room Theme" options that open skin selector
- Selected skin persists via SharedPreferences (using existing `keyCardSkin` / `keyRoomSkin` constants)

### Wave 9: Tests (~2 files)

**New**: `apps/flutter_app/test/unit/assets/asset_registry_test.dart`
- All skin IDs resolve to valid themes
- Default fallback works for unknown IDs
- All card skins have valid colour properties
- All room skins have valid gradient colours

**New**: `apps/flutter_app/test/widget/skins/playing_card_skin_test.dart`
- PlayingCardWidget renders correctly with each skin theme
- Card back uses correct gradient for each skin
- Default theme applied when no skin specified

---

## Key design decisions

### 1. Programmatic rendering, not image assets

Card faces are rendered with text + Unicode symbols. Card skins only change **colours and the card back design**. This means:
- Zero image files needed for cards
- No CDN or cache management for card assets
- App stays small
- New skins = new colour definitions (trivial to add)

Room skins change the **felt gradient colours** and **accent colour** — no background images.

### 2. AssetRegistry is synchronous

All skin themes are defined in code, so lookup is instant. No async loading needed. This simplifies the entire system compared to prompt 14's CDN-based approach.

### 3. Skin purchase flow

User taps "Buy" on SkinPreviewCard → `SkinService.purchaseSkin()` deducts currency → `UserSkin` created → skin appears as owned. User taps "Equip" → `SkinService.equipSkin()` → `selectedCardSkinProvider` / `selectedRoomSkinProvider` updated → all game widgets re-render with new theme.

### 4. Brand skins deferred

Prompt 14 describes a brand skin system with CDN delivery, manifests, and partner guidelines. **Defer this entirely.** It requires real CDN infrastructure and partnerships that don't exist yet. The current programmatic approach supports all built-in skins. Brand skins can be added later as image-based skins with a CDN loader.

### 5. Audio assets are path constants only

No audio files are being created in this session — just the path constant definitions and manager infrastructure. Actual audio file creation and integration happens when sound is hooked up end-to-end.

---

## File structure summary

**~12 new/upgraded files:**

```
apps/flutter_app/lib/
├── core/assets/
│   ├── card_skin_theme.dart          # NEW — CardSkinTheme + 4 presets
│   ├── room_skin_theme.dart          # NEW — RoomSkinTheme + 4 presets
│   ├── asset_registry.dart           # NEW — Singleton mapping skinId → theme
│   ├── audio_manager.dart            # NEW — Audio path management
│   └── audio_assets.dart             # NEW — Static const audio paths
├── core/di/
│   └── skin_theme_providers.dart     # NEW — cardSkinThemeProvider, roomSkinThemeProvider
├── shared/widgets/
│   ├── playing_card_widget.dart      # UPGRADE — use CardSkinTheme colours
│   ├── felt_background.dart          # UPGRADE — accept RoomSkinTheme
│   └── skins/
│       └── skin_selector.dart        # NEW — Grid selector with live previews
├── features/game/presentation/widgets/
│   └── card_hand.dart                # UPGRADE — pass skin theme to PlayingCardWidget
├── features/shop/presentation/
│   └── shop_screen.dart              # UPGRADE — wire to AssetRegistry + purchase flow
└── features/settings/presentation/
    └── settings_screen.dart          # UPGRADE — add skin selection options

apps/flutter_app/test/
├── unit/assets/
│   └── asset_registry_test.dart      # NEW
└── widget/skins/
    └── playing_card_skin_test.dart   # NEW
```

---

## Do NOT do these things

- Do NOT create PNG/SVG image files for card faces — keep programmatic rendering
- Do NOT implement CDN asset downloading — defer brand skins
- Do NOT use `Color.withValues()` — use `withOpacity()` (Flutter 3.24)
- Do NOT add `http` or `path_provider` dependencies for CDN loading
- Do NOT modify the existing `Skin` or `SkinType` in the monetization package
- Do NOT modify any Session 8/9 files (glass widgets, animation files)
- Do NOT modify the `GameOverDialog` or ad widgets from Session 12
- Do NOT modify the `social_core` package
- Do NOT use `DM Serif Display` font — Poppins + Inter only
- Do NOT create an `AssetManager` singleton with CDN logic — use the simpler `AssetRegistry`

---

## Testing guidance

After building:

```bash
# App should analyze cleanly
cd apps/flutter_app && fvm flutter analyze

# All app tests (target: ≥67/71 — no regressions from Session 12)
cd apps/flutter_app && fvm flutter test --timeout 60s
```

New tests to add:
- `test/unit/assets/asset_registry_test.dart` — registry returns correct themes, fallback for unknown IDs, all presets have valid properties
- `test/widget/skins/playing_card_skin_test.dart` — card renders with each skin, back uses correct gradient, default works without skin param

---

## Verification

```bash
# Static analysis
cd apps/flutter_app && fvm flutter analyze

# All app tests (should match or exceed Session 12 baseline of 67/71)
cd apps/flutter_app && fvm flutter test --timeout 60s

# Visual check: run app and verify
# 1. Open Shop → Card Skins tab shows 4 skins with live previews
# 2. Open Shop → Room Themes tab shows 4 themes with colour swatches
# 3. Equip a different card skin → play a game → cards render with new colours
# 4. Equip a different room theme → felt background changes colour
# 5. Settings screen shows current skin selections
```
