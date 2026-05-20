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
│   └── bidding_modal.dart        # Oh Hell bid modal
└── screens/
    └── oh_hell_screen.dart       # Full game screen
```

All widgets use `const` constructors where possible. State via Riverpod providers. No hardcoded colours — reference `AppColors` constants class.
