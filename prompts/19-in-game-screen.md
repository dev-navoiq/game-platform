# 19 - In-Game Screen (Oh Hell · Card Game Layout)

> **Prompt 19 of 19** | Implements the complete in-game screen for Oh Hell and other trick-taking card games. Builds on the glass UI components (prompt 09), animation system (prompt 10), and game screens shell (prompt 11).

---

## Overview

Build the fully interactive in-game screen for Oh Hell with support for 3–8 players. The design uses floating avatar nodes around the perimeter of the screen (no containing boxes), a central trick zone showing played cards in a grid layout, and a card fan at the bottom for the local player's hand.

Reference `00-design-system.md` for all colours, typography, glass morphism recipes, and animation conventions before writing any code.

---

## Directory Structure

```
lib/features/game/presentation/
├── screens/
│   └── oh_hell_game_screen.dart        # Main screen for Oh Hell
├── widgets/
│   ├── player_node.dart                # Floating avatar + name + bid pill
│   ├── trick_zone.dart                 # Central card grid with avatar badges
│   ├── card_fan.dart                   # Local player's hand fan
│   ├── playing_card_widget.dart        # Individual card (trick + hand variants)
│   ├── bid_pill.dart                   # Coloured bid status chip
│   ├── bidding_modal.dart              # Oh Hell bid selection modal
│   ├── turn_timer.dart                 # Circular countdown ring
│   ├── game_toast.dart                 # Contextual toast messages
│   └── emoji_bar.dart                  # Quick reaction buttons
```

---

## Screen Layout

The screen is a `Stack` over the felt table background. All elements are `Positioned` absolutely.

```
Stack(
  children: [
    FeltBackground(),           // gradient + texture overlay
    AmbientGlow(),              // bottom gold radial glow
    HudBar(),                   // top: GamePill + RoundInfo + MenuBtn
    GameToast(),                // below HUD, centred
    TurnTimer(),                // top-right, beside toast
    ...opponentNodes,           // positioned by seat (top/left/right)
    TrickZone(),                // centre of screen
    VoiceCluster(),             // bottom-left
    SideTabs(),                 // bottom-right
    EmojiBar(),                 // bottom-centre above hand
    HandArea(),                 // bottom: MyAvatar + BidStatus + CardFan
    if (isBidding) BiddingModal(),
  ]
)
```

---

## AppColors

Create or extend `lib/core/constants/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

class AppColors {
  // Felt table
  static const feltDark  = Color(0xFF122E1D);
  static const feltMid   = Color(0xFF1D4A2E);
  static const feltLight = Color(0xFF2A6641);

  // Accent gold
  static const accent     = Color(0xFFC47B2B);
  static const accentSoft = Color(0xFFE8A84F);
  static Color accentGlow = const Color(0xFFC47B2B).withOpacity(0.22);

  // Glass
  static Color glassBg     = Colors.white.withOpacity(0.52);
  static Color glassBorder = Colors.white.withOpacity(0.72);

  // Text
  static const textDark     = Color(0xFF241810);
  static const textMuted    = Color(0xFF9C7D62);
  static Color textOnFelt   = Colors.white.withOpacity(0.90);
  static Color textFeltMuted = Colors.white.withOpacity(0.50);

  // Status
  static const success = Color(0xFF27AE60);
  static const danger  = Color(0xFFE74C3C);

  // Cards
  static const cardBg    = Colors.white;
  static const cardRed   = Color(0xFFC0392B);
  static const cardBlack = Color(0xFF1A1A2A);

  // Avatar
  static const avatarBg1 = Color(0xFFF0E8DA);
  static const avatarBg2 = Color(0xFFE5D4BC);
}
```

---

## GlassMixin / GlassContainer

Create `lib/shared/widgets/glass_container.dart`:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blurSigma;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 100,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.blurSigma = 18,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3C2814).withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.55),
                blurRadius: 4,
                offset: const Offset(0, 1),
                spreadRadius: -1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
```

---

## PlayerNode Widget

`lib/features/game/presentation/widgets/player_node.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'bid_pill.dart';

class PlayerNode extends StatefulWidget {
  final String name;
  final String emoji;           // placeholder; swap for NetworkImage avatar
  final int won;
  final int bid;
  final bool isActive;          // currently their turn
  final bool hasPlayed;         // played a card this trick
  final bool isDealer;
  final bool isSmall;           // true for side column nodes (36px avatar)

  const PlayerNode({
    super.key,
    required this.name,
    required this.emoji,
    required this.won,
    required this.bid,
    this.isActive = false,
    this.hasPlayed = false,
    this.isDealer = false,
    this.isSmall = false,
  });

  @override
  State<PlayerNode> createState() => _PlayerNodeState();
}

class _PlayerNodeState extends State<PlayerNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 0.65).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avSize = widget.isSmall ? 36.0 : 40.0;
    final nameSize = widget.isSmall ? 8.5 : 9.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Active pulse dot ──
        if (widget.isActive)
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 7, height: 7,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: AppColors.accentSoft.withOpacity(_pulseAnim.value),
                  blurRadius: 6,
                )],
              ),
            ),
          )
        else
          const SizedBox(height: 10),

        // ── Avatar ──
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: avSize, height: avSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.avatarBg1, AppColors.avatarBg2],
                ),
                border: Border.all(
                  color: widget.isActive
                      ? AppColors.accent
                      : Colors.white.withOpacity(0.8),
                  width: widget.isActive ? 2.5 : 1.5,
                ),
                boxShadow: [
                  if (widget.isActive) BoxShadow(
                    color: AppColors.accentGlow,
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(widget.emoji,
                  style: TextStyle(fontSize: avSize * 0.50)),
              ),
            ),

            // Dealer badge
            if (widget.isDealer)
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 15, height: 15,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                  ),
                  child: const Center(
                    child: Text('D',
                      style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  ),
                ),
              ),

            // Has-played check badge
            if (widget.hasPlayed)
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 15, height: 15,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.95),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                    boxShadow: [BoxShadow(
                      color: AppColors.success.withOpacity(0.4),
                      blurRadius: 6,
                    )],
                  ),
                  child: const Center(
                    child: Text('✓',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 4),

        // ── Name ──
        SizedBox(
          width: 54,
          child: Text(
            widget.name.length > 8
                ? '${widget.name.substring(0, 7)}…'
                : widget.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: nameSize,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.52),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // ── Bid pill ──
        BidPill(won: widget.won, bid: widget.bid),
      ],
    );
  }
}
```

---

## BidPill Widget

`lib/features/game/presentation/widgets/bid_pill.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class BidPill extends StatelessWidget {
  final int won;
  final int bid;

  const BidPill({super.key, required this.won, required this.bid});

  Color get _bg {
    if (won > bid)  return AppColors.danger.withOpacity(0.22);
    if (won == bid) return AppColors.success.withOpacity(0.22);
    return Colors.white.withOpacity(0.15);
  }

  Color get _text {
    if (won > bid)  return AppColors.danger;
    if (won == bid) return AppColors.success;
    return Colors.white.withOpacity(0.75);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$won / $bid',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _text,
        ),
      ),
    );
  }
}
```

---

## PlayingCardWidget

`lib/features/game/presentation/widgets/playing_card_widget.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum CardSize { trick, hand }

class PlayingCardWidget extends StatelessWidget {
  final String rank;
  final String suit;
  final CardSize cardSize;
  final bool isSelected;
  final bool isInvalid;
  final bool isWinning;
  final bool isTrump;
  final String? avatarEmoji;   // shows avatar badge above card (trick cards)
  final bool avatarIsLeading;
  final double rotation;        // degrees

  const PlayingCardWidget({
    super.key,
    required this.rank,
    required this.suit,
    this.cardSize = CardSize.trick,
    this.isSelected = false,
    this.isInvalid = false,
    this.isWinning = false,
    this.isTrump = false,
    this.avatarEmoji,
    this.avatarIsLeading = false,
    this.rotation = 0,
  });

  bool get _isRed => suit == '♥' || suit == '♦';

  @override
  Widget build(BuildContext context) {
    final w = cardSize == CardSize.hand ? 62.0 : 56.0;
    final h = cardSize == CardSize.hand ? 90.0 : 80.0;
    final rankSize = cardSize == CardSize.hand ? 18.0 : 16.0;
    final suitSize = cardSize == CardSize.hand ? 13.0 : 12.0;

    final col = _isRed ? AppColors.cardRed : AppColors.cardBlack;

    Widget card = Transform.rotate(
      angle: rotation * (3.14159 / 180),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Card body ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: w, height: h,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(cardSize == CardSize.hand ? 9 : 8),
              border: Border.all(
                color: isWinning
                    ? AppColors.accent
                    : isTrump
                        ? AppColors.accent.withOpacity(0.55)
                        : const Color(0xFFC8B49B).withOpacity(0.35),
                width: isWinning ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (isWinning) BoxShadow(
                  color: AppColors.accent.withOpacity(0.32),
                  blurRadius: 20, spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 14, offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.6),
                  blurRadius: 3, offset: const Offset(0, 1),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Rank + suit top-left
                Positioned(
                  top: 5, left: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rank,
                        style: TextStyle(
                          fontFamily: 'DMSerifDisplay',
                          fontSize: rankSize,
                          fontWeight: FontWeight.w700,
                          color: col, height: 1,
                        )),
                      Text(suit,
                        style: TextStyle(
                          fontFamily: 'DMSerifDisplay',
                          fontSize: suitSize,
                          color: col, height: 1,
                        )),
                    ],
                  ),
                ),
                // Watermark suit
                Center(
                  child: Text(suit,
                    style: TextStyle(
                      fontFamily: 'DMSerifDisplay',
                      fontSize: cardSize == CardSize.hand ? 34.0 : 28.0,
                      color: col.withOpacity(0.07),
                    )),
                ),
              ],
            ),
          ),

          // Trump pip badge
          if (isTrump)
            Positioned(
              bottom: -6, right: -6,
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4, offset: const Offset(0, 2),
                  )],
                ),
                child: const Center(
                  child: Text('♦',
                    style: TextStyle(fontSize: 9, color: Colors.white)),
                ),
              ),
            ),

          // Avatar badge (trick cards only)
          if (avatarEmoji != null)
            Positioned(
              top: -9, left: 0, right: 0,
              child: Center(
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.avatarBg1, AppColors.avatarBg2],
                    ),
                    border: Border.all(
                      color: avatarIsLeading
                          ? AppColors.accent
                          : Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      if (avatarIsLeading) BoxShadow(
                        color: AppColors.accent.withOpacity(0.3),
                        blurRadius: 6,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 6, offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(avatarEmoji!,
                      style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Opacity for invalid hand cards
    if (isInvalid) {
      card = Opacity(opacity: 0.42, child: card);
    }

    return card;
  }
}
```

---

## TrickZone Widget

`lib/features/game/presentation/widgets/trick_zone.dart`

```dart
import 'package:flutter/material.dart';
import 'playing_card_widget.dart';

class PlayedCard {
  final String rank;
  final String suit;
  final String playerEmoji;
  final bool isTrump;
  final bool isWinning;

  const PlayedCard({
    required this.rank,
    required this.suit,
    required this.playerEmoji,
    this.isTrump = false,
    this.isWinning = false,
  });
}

class TrickZone extends StatelessWidget {
  final List<PlayedCard> cards;

  const TrickZone({super.key, required this.cards});

  static const double _cardW = 56;
  static const double _cardH = 80;
  static const double _gap   = 8;
  static const double _zoneW = 240;
  static const double _zoneH = 190;

  // Slight rotation per card for "tossed" feel
  static const _rotations = [-3.0, 4.0, -2.0, 3.0, -4.0, 2.0, -3.0, 4.0];

  List<Offset> _positions(int n) {
    if (n == 0) return [];

    if (n <= 4) {
      final totalW = n * _cardW + (n - 1) * _gap;
      final startX = (_zoneW - totalW) / 2;
      final y = (_zoneH - _cardH) / 2;
      return List.generate(n, (i) => Offset(startX + i * (_cardW + _gap), y));
    }

    // Two rows
    final row1n  = (n / 2).ceil();
    final row2n  = (n / 2).floor();
    final startY = (_zoneH - (2 * _cardH + _gap)) / 2;
    final positions = <Offset>[];

    final r1W   = row1n * _cardW + (row1n - 1) * _gap;
    final r1x   = (_zoneW - r1W) / 2;
    for (var i = 0; i < row1n; i++) {
      positions.add(Offset(r1x + i * (_cardW + _gap), startY));
    }

    final r2W   = row2n * _cardW + (row2n - 1) * _gap;
    final r2x   = (_zoneW - r2W) / 2;
    for (var i = 0; i < row2n; i++) {
      positions.add(Offset(r2x + i * (_cardW + _gap), startY + _cardH + _gap));
    }

    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final positions = _positions(cards.length);

    return SizedBox(
      width: _zoneW,
      height: _zoneH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient shadow under card pile
          Positioned.fill(
            child: Center(
              child: Container(
                width: 180, height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(55),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    spreadRadius: 4,
                  )],
                ),
              ),
            ),
          ),

          // Cards
          ...cards.asMap().entries.map((entry) {
            final i   = entry.key;
            final c   = entry.value;
            final pos = positions[i];
            final rot = _rotations[i % _rotations.length];

            return AnimatedPositioned(
              duration: Duration(milliseconds: 300 + i * 60),
              curve: Curves.easeOut,
              left: pos.dx,
              top:  pos.dy,
              child: PlayingCardWidget(
                rank: c.rank,
                suit: c.suit,
                isTrump: c.isTrump,
                isWinning: c.isWinning,
                avatarEmoji: c.playerEmoji,
                avatarIsLeading: c.isWinning,
                rotation: rot,
              ),
            );
          }),
        ],
      ),
    );
  }
}
```

---

## CardFan Widget

`lib/features/game/presentation/widgets/card_fan.dart`

```dart
import 'package:flutter/material.dart';
import 'playing_card_widget.dart';

class HandCard {
  final String rank;
  final String suit;
  final bool isInvalid;

  const HandCard({
    required this.rank,
    required this.suit,
    this.isInvalid = false,
  });
}

class CardFan extends StatefulWidget {
  final List<HandCard> cards;
  final ValueChanged<int>? onCardSelected;
  final int? selectedIndex;

  const CardFan({
    super.key,
    required this.cards,
    this.onCardSelected,
    this.selectedIndex,
  });

  @override
  State<CardFan> createState() => _CardFanState();
}

class _CardFanState extends State<CardFan> {
  static const double _cardW  = 62;
  static const double _maxSpread = 36;
  static const double _fanW   = 210;

  double get _spread =>
      widget.cards.length > 1
          ? (_fanW / (widget.cards.length - 1)).clamp(0, _maxSpread)
          : 0;

  @override
  Widget build(BuildContext context) {
    final n = widget.cards.length;

    return SizedBox(
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: widget.cards.asMap().entries.map((entry) {
          final i   = entry.key;
          final c   = entry.value;
          final off = i - (n - 1) / 2;
          final x   = off * _spread;
          final angleDeg = off * 4.5;
          final yOff = (off.abs() * 2.5);
          final isSelected = widget.selectedIndex == i;

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: const Cubic(0.34, 1.56, 0.64, 1),
            left: (MediaQuery.of(context).size.width / 2) - 31 + x - 130,
            bottom: 0 + yOff + (isSelected ? 20 : 0),
            child: AnimatedZIndex(
              zIndex: isSelected ? 99 : i + 1,
              child: GestureDetector(
                onTap: c.isInvalid ? null : () => widget.onCardSelected?.call(i),
                child: Transform.rotate(
                  angle: angleDeg * (3.14159 / 180),
                  alignment: Alignment.bottomCenter,
                  child: PlayingCardWidget(
                    rank: c.rank,
                    suit: c.suit,
                    cardSize: CardSize.hand,
                    isSelected: isSelected,
                    isInvalid: c.isInvalid,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Simple z-index wrapper using Stack ordering
class AnimatedZIndex extends StatelessWidget {
  final Widget child;
  final int zIndex;
  const AnimatedZIndex({super.key, required this.child, required this.zIndex});

  @override
  Widget build(BuildContext context) => child;
}
```

---

## TurnTimer Widget

`lib/features/game/presentation/widgets/turn_timer.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class TurnTimer extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback? onExpired;

  const TurnTimer({
    super.key,
    this.totalSeconds = 15,
    this.onExpired,
  });

  @override
  State<TurnTimer> createState() => _TurnTimerState();
}

class _TurnTimerState extends State<TurnTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    )..forward().whenComplete(() => widget.onExpired?.call());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38, height: 38,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final remaining =
              (widget.totalSeconds * (1 - _ctrl.value)).ceil();
          return Stack(
            alignment: Alignment.center,
            children: [
              // Ring
              CustomPaint(
                size: const Size(38, 38),
                painter: _TimerPainter(progress: 1 - _ctrl.value),
              ),
              // Number
              Text(
                '$remaining',
                style: const TextStyle(
                  fontFamily: 'DMSerifDisplay',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimerPainter extends CustomPainter {
  final double progress;
  _TimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = 16.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(
      rect, -3.14159 / 2, 2 * 3.14159, false,
      Paint()
        ..color = Colors.white.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Fill
    if (progress > 0) {
      canvas.drawArc(
        rect, -3.14159 / 2, 2 * 3.14159 * progress, false,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerPainter old) => old.progress != progress;
}
```

---

## BiddingModal Widget

`lib/features/game/presentation/widgets/bidding_modal.dart`

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_container.dart';

class BiddingModal extends StatefulWidget {
  final int cardsDealt;
  final int forbiddenBid;   // dealer cannot bid this value
  final bool isDealer;
  final ValueChanged<int> onBidConfirmed;

  const BiddingModal({
    super.key,
    required this.cardsDealt,
    required this.forbiddenBid,
    required this.isDealer,
    required this.onBidConfirmed,
  });

  @override
  State<BiddingModal> createState() => _BiddingModalState();
}

class _BiddingModalState extends State<BiddingModal> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: const Color(0xFF0A1C10).withOpacity(0.22),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: const Cubic(0.34, 1.56, 0.64, 1),
              builder: (_, v, child) => Transform.scale(
                scale: 0.88 + 0.12 * v,
                child: Opacity(opacity: v, child: child),
              ),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 56, offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Place Your Bid',
                      style: const TextStyle(
                        fontFamily: 'DMSerifDisplay', fontSize: 19,
                        color: AppColors.textDark,
                      )),
                    const SizedBox(height: 4),
                    Text('How many tricks will you win?',
                      style: TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
                    const SizedBox(height: 12),

                    // Forbidden bid warning
                    if (widget.isDealer)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accent.withOpacity(0.15)),
                        ),
                        child: Text.rich(TextSpan(
                          children: [
                            const TextSpan(text: '⚠️ Dealer cannot bid '),
                            TextSpan(
                              text: '${widget.forbiddenBid}',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          style: TextStyle(
                            fontSize: 10.5, color: AppColors.textMuted),
                        )),
                      ),

                    const SizedBox(height: 14),

                    // Bid grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1,
                      ),
                      itemCount: widget.cardsDealt + 1,
                      itemBuilder: (_, i) {
                        final isForbidden = widget.isDealer && i == widget.forbiddenBid;
                        final isSelected  = _selected == i;

                        return GestureDetector(
                          onTap: isForbidden ? null : () => setState(() => _selected = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent
                                  : Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.accent.withOpacity(0.18),
                              ),
                              boxShadow: isSelected ? [BoxShadow(
                                color: AppColors.accent.withOpacity(0.3),
                                blurRadius: 10, offset: const Offset(0, 3),
                              )] : null,
                            ),
                            child: Center(
                              child: Text('$i',
                                style: TextStyle(
                                  fontFamily: 'DMSerifDisplay',
                                  fontSize: 16,
                                  color: isForbidden
                                      ? AppColors.textMuted.withOpacity(0.35)
                                      : isSelected
                                          ? Colors.white
                                          : AppColors.textDark,
                                  decoration: isForbidden
                                      ? TextDecoration.lineThrough
                                      : null,
                                )),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _selected == null ? null : () {
                          widget.onBidConfirmed(_selected!);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _selected == null
                                ? AppColors.accent.withOpacity(0.4)
                                : AppColors.accent,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: _selected == null ? null : [BoxShadow(
                              color: AppColors.accent.withOpacity(0.35),
                              blurRadius: 14, offset: const Offset(0, 5),
                            )],
                          ),
                          child: const Center(
                            child: Text('Confirm Bid →',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.1,
                              )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

## Riverpod State

Create `lib/features/game/presentation/providers/oh_hell_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'oh_hell_providers.freezed.dart';

@freezed
class OhHellGameState with _$OhHellGameState {
  const factory OhHellGameState({
    required List<OhHellPlayer> players,
    required List<TrickCard> currentTrick,
    required String localPlayerId,
    required int round,
    required int cardsDealt,
    required String trumpSuit,
    @Default(false) bool isBidding,
    @Default(false) bool isLocalPlayerTurn,
    required List<String> localHand,  // list of "rank|suit" e.g. "A|♠"
    int? selectedCardIndex,
  }) = _OhHellGameState;
}

@freezed
class OhHellPlayer with _$OhHellPlayer {
  const factory OhHellPlayer({
    required String id,
    required String name,
    required String emoji,
    required int bid,
    required int tricksWon,
    required bool isDealer,
    @Default(false) bool isActive,
    @Default(false) bool hasPlayedThisTrick,
  }) = _OhHellPlayer;
}

@freezed
class TrickCard with _$TrickCard {
  const factory TrickCard({
    required String rank,
    required String suit,
    required String playerEmoji,
    @Default(false) bool isTrump,
    @Default(false) bool isWinning,
  }) = _TrickCard;
}

final ohHellGameProvider =
    StateNotifierProvider<OhHellGameNotifier, OhHellGameState>((ref) {
  return OhHellGameNotifier();
});

class OhHellGameNotifier extends StateNotifier<OhHellGameState> {
  OhHellGameNotifier() : super(_initialState);

  static final _initialState = OhHellGameState(
    players: [], currentTrick: [], localPlayerId: '',
    round: 1, cardsDealt: 7, trumpSuit: '♦',
    localHand: [],
  );

  void selectCard(int index) {
    state = state.copyWith(
      selectedCardIndex: state.selectedCardIndex == index ? null : index,
    );
  }

  void playCard(int index) {
    // TODO: validate move, update trick, emit to Supabase Realtime
  }

  void placeBid(int bid) {
    // TODO: record bid, advance bidding to next player
    state = state.copyWith(isBidding: false);
  }
}
```

---

## Main Screen

`lib/features/game/presentation/screens/oh_hell_game_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../providers/oh_hell_providers.dart';
import '../widgets/player_node.dart';
import '../widgets/trick_zone.dart';
import '../widgets/card_fan.dart';
import '../widgets/turn_timer.dart';
import '../widgets/bidding_modal.dart';

class OhHellGameScreen extends ConsumerWidget {
  const OhHellGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(ohHellGameProvider);
    final opponents = game.players
        .where((p) => p.id != game.localPlayerId)
        .toList();
    final me = game.players.firstWhere(
      (p) => p.id == game.localPlayerId,
      orElse: () => const OhHellPlayer(
        id: '', name: 'You', emoji: '🐯', bid: 3, tricksWon: 2, isDealer: false,
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ──
          _FeltBackground(),

          // ── HUD ──
          Positioned(
            top: 40, left: 10, right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GlassContainer(
                  padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
                  child: Row(children: [
                    _IconBox('🃏'),
                    const SizedBox(width: 5),
                    const Text('Oh Hell!',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  ]),
                ),
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(children: [
                    Text('Round ${game.round}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                    const SizedBox(width: 5),
                    Text(game.trumpSuit,
                      style: const TextStyle(fontSize: 15, color: AppColors.cardRed)),
                    const SizedBox(width: 5),
                    Text('${game.cardsDealt} cards',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ]),
                ),
                GlassContainer(
                  padding: const EdgeInsets.all(0),
                  borderRadius: 17,
                  child: SizedBox(width: 34, height: 34,
                    child: const Icon(Icons.more_horiz, color: AppColors.textDark)),
                ),
              ],
            ),
          ),

          // ── Toast ──
          Positioned(
            top: 92, left: 0, right: 0,
            child: Center(
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                child: Text(
                  game.isLocalPlayerTurn
                      ? '✨ Your turn — play a card'
                      : '⏳ Waiting for ${opponents.firstWhere((p)=>p.isActive, orElse:()=>opponents.first).name}…',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
              ),
            ),
          ),

          // ── Timer ──
          if (game.isLocalPlayerTurn)
            Positioned(
              top: 92, right: 14,
              child: TurnTimer(
                totalSeconds: 15,
                onExpired: () {}, // auto-play lowest card
              ),
            ),

          // ── Opponents ──
          ..._positionOpponents(opponents),

          // ── Trick Zone ──
          Positioned(
            top: 195, left: 60, right: 60, bottom: 215,
            child: Center(
              child: TrickZone(
                cards: game.currentTrick.map((c) => PlayedCard(
                  rank: c.rank, suit: c.suit,
                  playerEmoji: c.playerEmoji,
                  isTrump: c.isTrump,
                  isWinning: c.isWinning,
                )).toList(),
              ),
            ),
          ),

          // ── Voice / Tabs / Emoji ──
          Positioned(
            left: 10, bottom: 190,
            child: Column(
              children: [
                _VoiceBtn(speaking: true),
                const SizedBox(height: 5),
                _VoiceBtn(speaking: false),
              ],
            ),
          ),

          // ── Hand area ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Meta row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        _MyAvatar(me.emoji),
                        const SizedBox(width: 7),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You',
                              style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.92))),
                            Text('Your turn',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.white.withOpacity(0.4))),
                          ],
                        ),
                      ]),
                      _BidStatusBadge(won: me.tricksWon, bid: me.bid),
                    ],
                  ),
                ),

                // Card fan
                CardFan(
                  cards: game.localHand.map((s) {
                    final parts = s.split('|');
                    return HandCard(rank: parts[0], suit: parts[1]);
                  }).toList(),
                  selectedIndex: game.selectedCardIndex,
                  onCardSelected: (i) =>
                      ref.read(ohHellGameProvider.notifier).selectCard(i),
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),

          // ── Bidding Modal ──
          if (game.isBidding)
            BiddingModal(
              cardsDealt: game.cardsDealt,
              forbiddenBid: 3, // TODO: compute from game state
              isDealer: me.isDealer,
              onBidConfirmed: (bid) =>
                  ref.read(ohHellGameProvider.notifier).placeBid(bid),
            ),
        ],
      ),
    );
  }

  /// Position opponent PlayerNodes based on count
  List<Widget> _positionOpponents(List<OhHellPlayer> opponents) {
    final n = opponents.length + 1; // +1 for local player
    final widgets = <Widget>[];
    List<OhHellPlayer> top=[], left=[], right=[];

    if (n <= 4) {
      top = opponents;
    } else if (n <= 6) {
      top   = opponents.sublist(0, n-3);
      left  = [opponents[n-3]];
      right = [opponents[n-2]];
    } else {
      top   = opponents.sublist(0, 3);
      left  = opponents.sublist(3, 5);
      right = opponents.sublist(5);
    }

    // Top row
    if (top.isNotEmpty) {
      widgets.add(Positioned(
        top: 122, left: 0, right: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: top.map((p) => _buildNode(p, false)).toList(),
        ),
      ));
    }

    // Left column
    if (left.isNotEmpty) {
      widgets.add(Positioned(
        left: 8, top: 0, bottom: 215,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: left.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildNode(p, true),
            )).toList(),
          ),
        ),
      ));
    }

    // Right column
    if (right.isNotEmpty) {
      widgets.add(Positioned(
        right: 8, top: 0, bottom: 215,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: right.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildNode(p, true),
            )).toList(),
          ),
        ),
      ));
    }

    return widgets;
  }

  Widget _buildNode(OhHellPlayer p, bool isSmall) => PlayerNode(
    name: p.name, emoji: p.emoji,
    won: p.tricksWon, bid: p.bid,
    isActive: p.isActive,
    hasPlayed: p.hasPlayedThisTrick,
    isDealer: p.isDealer,
    isSmall: isSmall,
  );
}

// ── Private sub-widgets ──

class _FeltBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, 0.45, 1],
          colors: [AppColors.feltLight, AppColors.feltMid, AppColors.feltDark],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final String emoji;
  const _IconBox(this.emoji);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentSoft],
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 13))),
    );
  }
}

class _MyAvatar extends StatelessWidget {
  final String emoji;
  const _MyAvatar(this.emoji);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFF5EDE0), Color(0xFFE8D5BA)],
        ),
        border: Border.all(color: AppColors.accent, width: 2.5),
        boxShadow: [BoxShadow(
          color: AppColors.accent.withOpacity(0.18),
          blurRadius: 0, spreadRadius: 3,
        )],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
    );
  }
}

class _BidStatusBadge extends StatelessWidget {
  final int won, bid;
  const _BidStatusBadge({required this.won, required this.bid});

  @override
  Widget build(BuildContext context) {
    final onTrack = won <= bid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: (onTrack ? AppColors.success : AppColors.danger).withOpacity(0.18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: (onTrack ? AppColors.success : AppColors.danger).withOpacity(0.28)),
      ),
      child: Text('$won / $bid bid',
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: onTrack ? AppColors.success : AppColors.danger,
        )),
    );
  }
}

class _VoiceBtn extends StatelessWidget {
  final bool speaking;
  const _VoiceBtn({required this.speaking});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 11,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 34, height: 34,
        child: Center(
          child: Text(speaking ? '🎙️' : '🔇',
            style: const TextStyle(fontSize: 15)),
        ),
      ),
    );
  }
}
```

---

## Testing

Add to `test/features/game/`:

```dart
// player_node_test.dart — verify active ring appears when isActive: true
// bid_pill_test.dart    — verify green/red/neutral colours
// trick_zone_test.dart  — verify 2-row layout kicks in at n > 4 cards
// card_fan_test.dart    — verify spread calculation and rotation angles
```

---

## Expected Output

Running this prompt produces:
- A fully interactive Oh Hell game screen supporting 3–8 players
- All widgets named, typed, and Riverpod-connected
- Glass morphism applied consistently via `GlassContainer`
- Animations for card entry, active player, turn timer, modal
- Bid modal enforcing the Oh Hell dealer constraint
- Layout adapts automatically by player count
