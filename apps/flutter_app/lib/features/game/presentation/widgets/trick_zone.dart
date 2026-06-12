import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/playing_card_widget.dart';
import 'card_hand.dart';
import 'seat_layout.dart';

/// Central trick area showing played cards positioned toward whoever played
/// them.
///
/// When [playerOrder] + [localPlayerId] are both supplied, each played card
/// is placed on the vector from table-center toward its player's seat — so
/// the card at the south slot belongs to the local player, the card at the
/// north slot belongs to the player across the table, etc. The shape works
/// for 2..8 players via [SeatLayout].
///
/// When [localPlayerId] is null (e.g. Hearts/Spades shells that haven't been
/// wired up yet) the widget falls back to the legacy single-row grid so
/// nothing visually breaks.
class TrickZone extends StatefulWidget {
  final List<TrickCard> currentTrick;
  final List<String> playerOrder;
  final Map<String, String> playerEmojis;
  final String? winningPlayerId;
  final Suit? trumpSuit;
  final Map<String, GlobalKey>? seatKeys;
  final String? localPlayerId;
  final String? lastTrickWinnerId;
  final Duration trickHold;
  final int fullTrickSize;

  const TrickZone({
    super.key,
    required this.currentTrick,
    required this.playerOrder,
    this.playerEmojis = const {},
    this.winningPlayerId,
    this.trumpSuit,
    this.seatKeys,
    this.localPlayerId,
    this.lastTrickWinnerId,
    this.trickHold = const Duration(milliseconds: 1800),
    this.fullTrickSize = 4,
  });

  // ── Layout constants ──────────────────────────────────────────
  // Cards in the trick are intentionally LARGER than hand cards
  // (CardFanAnimation uses 80×112) so the center clearly reads as the focal
  // point. Ratio 96:134 matches a standard playing-card aspect (~0.717).
  static const double _cardW = 96;
  static const double _cardH = 134;
  static const double _zoneW = 320;
  static const double _zoneH = 304;
  // Vector radii: how far each card's center sits from zone center along
  // the seat vector. Asymmetric so north/south get enough vertical room
  // for the taller card dimension (134) — symmetric kR=56 left the
  // north and south cards visibly overlapping. kR_v gives 18px clearance
  // between vertical neighbours, kR_h keeps horizontal pairs comfortable.
  static const double _kRv = 76;
  // kR_h bumped from 56 to 97 so the diagonal corners of N/S cards (centred
  // at x=160, occupying x ∈ [112, 208]) no longer overlap the inner edges of
  // W/E cards. With kRh=97, W sits at x_center=63 (right edge 111 < N left
  // edge 112) and E sits at x_center=257 (left edge 209 > N right edge 208).
  // Zone width 320 accommodates W_left=15 and E_right=305 comfortably.
  static const double _kRh = 97;
  // Small tilt per card index — adds visual interest without obscuring
  // who-played-what (the vector position carries that signal now).
  // Per-card rotations zeroed. The CardHand flight ends at rotation 0;
  // if the trick zone applies a non-zero rotation when the card "lands"
  // there's a visible rotation snap. Holding all cards at 0° means the
  // local flight hands off seamlessly.
  static const _rotations = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  @override
  State<TrickZone> createState() => _TrickZoneState();
}

class _TrickZoneState extends State<TrickZone> {
  final Set<String> _midFlight = {};
  final Map<String, OverlayEntry> _flightEntries = {};
  String? _lastWinnerIdDispatched;
  // Dim non-winning cards only after a brief beat — so the user sees the
  // full bright trick first, then watches the losers fade. Driven by a
  // timer in didUpdateWidget so the AnimatedOpacity has a stable target.
  bool _dimActive = false;
  Timer? _dimStartTimer;


  String _trickCardKey(TrickCard c) =>
      '${c.playerId}:${c.card.suit.name}:${c.card.rank.name}';

  /// Map each TrickCard to its top-left position inside the zone. Vector
  /// layout when seats are computable, grid fallback otherwise.
  List<Offset> _calculatePositions(List<TrickCard> trick) {
    if (trick.isEmpty) return const [];
    final seatMap = _seatMap();
    if (seatMap == null) return _gridFallback(trick.length);

    final cx = TrickZone._zoneW / 2;
    final cy = TrickZone._zoneH / 2;
    return trick.map((tc) {
      final seat = seatMap[tc.playerId];
      // Defensive: if a played card's playerId isn't in the seat map
      // (shouldn't happen but engine state can race), drop it at center.
      final sx = seat?.alignment.x ?? 0.0;
      final sy = seat?.alignment.y ?? 0.0;
      return Offset(
        cx + sx * TrickZone._kRh - TrickZone._cardW / 2,
        cy + sy * TrickZone._kRv - TrickZone._cardH / 2,
      );
    }).toList();
  }

  /// Build a playerId → SeatPosition lookup using SeatLayout. Returns null
  /// if we can't compute seats (no localPlayerId, or local not in order).
  Map<String, SeatPosition>? _seatMap() {
    final localId = widget.localPlayerId;
    if (localId == null) return null;
    final localIdx = widget.playerOrder.indexOf(localId);
    if (localIdx < 0) return null;
    final seats = SeatLayout.calculate(
      playerCount: widget.playerOrder.length,
      localPlayerIndex: localIdx,
    );
    return {
      for (final s in seats) widget.playerOrder[s.seatIndex]: s,
    };
  }

  /// Legacy single-row centered grid for screens that don't pass seat info.
  List<Offset> _gridFallback(int n) {
    const cardW = TrickZone._cardW;
    const cardH = TrickZone._cardH;
    const gap = 12.0;
    final totalW = n * cardW + (n - 1) * gap;
    final startX = (TrickZone._zoneW - totalW) / 2;
    final y = (TrickZone._zoneH - cardH) / 2;
    return List.generate(n, (i) => Offset(startX + i * (cardW + gap), y));
  }

  @override
  void didUpdateWidget(covariant TrickZone oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect newly added trick cards and animate non-local from seat to slot.
    final oldKeys = oldWidget.currentTrick.map(_trickCardKey).toSet();
    final newPositions = _calculatePositions(widget.currentTrick);
    for (var i = 0; i < widget.currentTrick.length; i++) {
      final tc = widget.currentTrick[i];
      final key = _trickCardKey(tc);
      if (oldKeys.contains(key)) continue;
      if (tc.playerId == widget.localPlayerId) continue;
      if (_midFlight.contains(key)) continue;
      final seatKey = widget.seatKeys?[tc.playerId];
      if (seatKey?.currentContext == null) continue;
      _midFlight.add(key);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startOpponentFlight(
          trickCard: tc,
          slotPosition: newPositions[i],
          flightKey: key,
        );
      });
    }

    // Dim state machine: stay bright for 500ms after the trick becomes
    // complete (so the user reads the full result), then fade losers.
    final wasFull = oldWidget.currentTrick.length >= oldWidget.fullTrickSize;
    final isFull = widget.currentTrick.length >= widget.fullTrickSize;
    if (isFull && !wasFull) {
      _dimStartTimer?.cancel();
      _dimStartTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _dimActive = true);
      });
    } else if (!isFull && (_dimActive || _dimStartTimer != null)) {
      _dimStartTimer?.cancel();
      _dimStartTimer = null;
      _dimActive = false;
    }

    // Trick collect animation — runs after the trick is complete.
    if (widget.lastTrickWinnerId != null &&
        widget.lastTrickWinnerId != _lastWinnerIdDispatched &&
        widget.currentTrick.length >= widget.fullTrickSize) {
      _lastWinnerIdDispatched = widget.lastTrickWinnerId;
      final winnerId = widget.lastTrickWinnerId!;
      final trickSnapshot = List<TrickCard>.from(widget.currentTrick);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleTrickCollect(
          winnerId: winnerId,
          trickSnapshot: trickSnapshot,
        );
      });
    }
  }

  @override
  void dispose() {
    _dimStartTimer?.cancel();
    for (final entry in _flightEntries.values) {
      entry.remove();
    }
    _flightEntries.clear();
    _midFlight.clear();
    super.dispose();
  }

  void _startOpponentFlight({
    required TrickCard trickCard,
    required Offset slotPosition,
    required String flightKey,
  }) {
    final seatKey = widget.seatKeys?[trickCard.playerId];
    final seatCtx = seatKey?.currentContext;
    final selfCtx = context;
    if (seatCtx == null || !mounted) {
      _midFlight.remove(flightKey);
      if (mounted) setState(() {});
      return;
    }

    final seatBox = seatCtx.findRenderObject() as RenderBox?;
    final selfBox = selfCtx.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(selfCtx);
    if (seatBox == null || selfBox == null) {
      _midFlight.remove(flightKey);
      if (mounted) setState(() {});
      return;
    }

    final seatRect = seatBox.localToGlobal(Offset.zero) & seatBox.size;
    final slotGlobalTopLeft = selfBox.localToGlobal(slotPosition);
    final slotRect =
        slotGlobalTopLeft & const Size(TrickZone._cardW, TrickZone._cardH);

    final startCenter = seatRect.center;
    final endCenter = slotRect.center;

    final emoji = widget.playerEmojis[trickCard.playerId] ?? '🎮';
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return _OpponentCardFlight(
          startCenter: startCenter,
          endCenter: endCenter,
          trumpSuit: widget.trumpSuit,
          trickCard: trickCard,
          emoji: emoji,
          onComplete: () {
            if (!mounted) {
              _flightEntries.remove(flightKey)?.remove();
              return;
            }
            _flightEntries.remove(flightKey)?.remove();
            _midFlight.remove(flightKey);
            setState(() {});
          },
        );
      },
    );
    _flightEntries[flightKey] = entry;
    overlay.insert(entry);
    setState(() {});
  }

  void _scheduleTrickCollect({
    required String winnerId,
    required List<TrickCard> trickSnapshot,
  }) {
    Future.delayed(widget.trickHold, () {
      if (!mounted) return;
      final selfBox = context.findRenderObject() as RenderBox?;
      final winnerKey = widget.seatKeys?[winnerId];
      final winnerCtx = winnerKey?.currentContext;
      if (selfBox == null || winnerCtx == null) {
        // Cards just vanish instead of swooping when this fires — log the
        // reason so we can tell whether it's the local winner (no PlayerNode
        // for the south seat) or a missed seat-key registration.
        // ignore: avoid_print
        print('[TrickZone] collect bailed: winnerId=$winnerId '
            'selfBox=${selfBox != null} '
            'winnerKey=${winnerKey != null} '
            'winnerCtx=${winnerCtx != null} '
            'keys=${widget.seatKeys?.keys.toList()}');
        return;
      }
      final winnerBox = winnerCtx.findRenderObject() as RenderBox?;
      if (winnerBox == null) {
        // ignore: avoid_print
        print('[TrickZone] collect bailed: winnerBox null for $winnerId');
        return;
      }

      final selfTopLeft = selfBox.localToGlobal(Offset.zero);
      final positions = _calculatePositions(trickSnapshot);
      final cards = <Widget>[];
      final localPositions = <Offset>[];
      const cxOffset = TrickZone._zoneW / 2 - TrickZone._cardW / 2;
      const cyOffset = TrickZone._zoneH / 2 - TrickZone._cardH / 2;
      for (var i = 0; i < trickSnapshot.length; i++) {
        final rot = TrickZone._rotations[i % TrickZone._rotations.length];
        cards.add(_TrickCardWithBadge(
          trickCard: trickSnapshot[i],
          emoji: widget.playerEmojis[trickSnapshot[i].playerId] ?? '🎮',
          rotation: rot,
          isWinning: trickSnapshot[i].playerId == winnerId,
          isTrump: widget.trumpSuit != null &&
              trickSnapshot[i].card.suit == widget.trumpSuit,
        ));
        // Position relative to the zone's center for the collect animation.
        localPositions.add(Offset(
          positions[i].dx - cxOffset,
          positions[i].dy - cyOffset,
        ));
      }

      final winnerCenter =
          winnerBox.localToGlobal(winnerBox.size.center(Offset.zero));
      final zoneCenter = selfTopLeft +
          const Offset(TrickZone._zoneW / 2, TrickZone._zoneH / 2);
      final winnerOffset = winnerCenter - zoneCenter;
      const overlaySize = Size(TrickZone._zoneW, TrickZone._zoneH);
      final overlayTopLeft =
          zoneCenter - Offset(overlaySize.width / 2, overlaySize.height / 2);

      late OverlayEntry collectEntry;
      collectEntry = OverlayEntry(builder: (ctx) {
        return Positioned(
          left: overlayTopLeft.dx,
          top: overlayTopLeft.dy,
          width: overlaySize.width,
          height: overlaySize.height,
          child: IgnorePointer(
            child: _TrickCollectOverlay(
              cards: cards,
              cardPositions: localPositions,
              winnerOffset: winnerOffset,
              onComplete: () {
                collectEntry.remove();
              },
            ),
          ),
        );
      });
      Overlay.of(context).insert(collectEntry);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentTrick.isEmpty) {
      return const SizedBox(
        width: TrickZone._zoneW,
        height: TrickZone._zoneH,
      );
    }

    final positions = _calculatePositions(widget.currentTrick);

    return SizedBox(
      width: TrickZone._zoneW,
      height: TrickZone._zoneH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient shadow under card pile.
          Center(
            child: Container(
              width: 240,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(80),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 22,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
          ),

          // Cards. When the trick is complete and a winner is known, dim
          // the losing cards so the winning card visually pops without
          // needing a separate toast overlay.
          ...widget.currentTrick.asMap().entries.map((entry) {
            final i = entry.key;
            final trickCard = entry.value;
            final pos = positions[i];
            final rot =
                TrickZone._rotations[i % TrickZone._rotations.length];
            final isWinning =
                trickCard.playerId == widget.winningPlayerId;
            final isTrump = widget.trumpSuit != null &&
                trickCard.card.suit == widget.trumpSuit;
            final emoji =
                widget.playerEmojis[trickCard.playerId] ?? '🎮';
            final isMidFlight =
                _midFlight.contains(_trickCardKey(trickCard));
            // Non-winning cards dim once the result is known AND a brief
            // beat (500ms) has passed — that beat lets the user register
            // all 4 cards at full brightness before the losers fade.
            final trickComplete =
                widget.currentTrick.length >= widget.fullTrickSize &&
                    widget.winningPlayerId != null;
            final isDimmed = trickComplete && _dimActive && !isWinning;

            return AnimatedPositioned(
              key: ValueKey(_trickCardKey(trickCard)),
              duration: Duration(milliseconds: 280 + i * 50),
              curve: Curves.easeOutCubic,
              left: pos.dx,
              top: pos.dy,
              // No fade — the flight overlay carries the badge through
              // transit so swapping it for the underlying card is a clean
              // 1-frame swap. A 120ms AnimatedOpacity here is what made
              // the badge appear to "fade in" after the card had already
              // landed.
              child: Opacity(
                opacity: isMidFlight ? 0 : 1,
                child: _TrickCardWithBadge(
                  trickCard: trickCard,
                  emoji: emoji,
                  rotation: rot,
                  isWinning: isWinning,
                  isTrump: isTrump,
                  isDimmed: isDimmed,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}


class _OpponentCardFlight extends StatefulWidget {
  final Offset startCenter;
  final Offset endCenter;
  final TrickCard trickCard;
  final Suit? trumpSuit;
  final String emoji;
  final VoidCallback onComplete;

  const _OpponentCardFlight({
    required this.startCenter,
    required this.endCenter,
    required this.trickCard,
    required this.trumpSuit,
    required this.emoji,
    required this.onComplete,
  });

  @override
  State<_OpponentCardFlight> createState() => _OpponentCardFlightState();
}

class _OpponentCardFlightState extends State<_OpponentCardFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward().then((_) {
      if (!mounted) return;
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        final t = _curve.value;
        final dx = widget.startCenter.dx +
            (widget.endCenter.dx - widget.startCenter.dx) * t;
        final dy = widget.startCenter.dy +
            (widget.endCenter.dy - widget.startCenter.dy) * t;
        return Positioned(
          left: dx - TrickZone._cardW / 2,
          top: dy - TrickZone._cardH / 2,
          child: IgnorePointer(
            child: _TrickCardWithBadge(
              trickCard: widget.trickCard,
              emoji: widget.emoji,
              rotation: 0,
              isWinning: false,
              isTrump: widget.trumpSuit != null &&
                  widget.trickCard.card.suit == widget.trumpSuit,
            ),
          ),
        );
      },
    );
  }
}

class _TrickCollectOverlay extends StatelessWidget {
  final List<Widget> cards;
  final List<Offset> cardPositions;
  final Offset winnerOffset;
  final VoidCallback onComplete;

  const _TrickCollectOverlay({
    required this.cards,
    required this.cardPositions,
    required this.winnerOffset,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return _DirectTrickCollect(
      cards: cards,
      cardPositions: cardPositions,
      winnerOffset: winnerOffset,
      onComplete: onComplete,
    );
  }
}

class _DirectTrickCollect extends StatefulWidget {
  final List<Widget> cards;
  final List<Offset> cardPositions;
  final Offset winnerOffset;
  final VoidCallback onComplete;

  const _DirectTrickCollect({
    required this.cards,
    required this.cardPositions,
    required this.winnerOffset,
    required this.onComplete,
  });

  @override
  State<_DirectTrickCollect> createState() => _DirectTrickCollectState();
}

class _DirectTrickCollectState extends State<_DirectTrickCollect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Slowed from 700ms so the "all cards travel together to the winner"
      // moment reads as a deliberate beat rather than a quick wipe.
      duration: const Duration(milliseconds: 950),
    )..forward().then((_) {
        if (!mounted) return;
        widget.onComplete();
      });
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
      builder: (context, _) {
        final t = _controller.value;
        final gather = Curves.easeInOut.transform((t / 0.4).clamp(0.0, 1.0));
        final slide =
            Curves.easeInCubic.transform(((t - 0.3) / 0.55).clamp(0.0, 1.0));
        final fade = ((t - 0.55) / 0.45).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: List.generate(widget.cards.length, (index) {
            final cardPos = index < widget.cardPositions.length
                ? widget.cardPositions[index]
                : Offset.zero;

            final gathered = Offset(
              cardPos.dx * (1 - gather),
              cardPos.dy * (1 - gather),
            );
            final finalPos = Offset(
              gathered.dx + widget.winnerOffset.dx * slide,
              gathered.dy + widget.winnerOffset.dy * slide,
            );
            final scale = 1.0 - (slide * 0.35);
            final opacity = (1.0 - fade).clamp(0.0, 1.0);

            return Transform.translate(
              offset: finalPos,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: widget.cards[index],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Trick card render: delegates the face to [PlayingCardWidget] (single
/// source of truth for skin + sizing) and layers an avatar badge above +
/// optional winning glow / trump tint around it.
class _TrickCardWithBadge extends StatelessWidget {
  final TrickCard trickCard;
  final String emoji;
  final double rotation;
  final bool isWinning;
  final bool isTrump;
  /// When true, the card renders at ~38% opacity — used to dim losing
  /// cards while the winning card stays bright. Animates so the dim
  /// doesn't feel like a hard cut.
  final bool isDimmed;

  const _TrickCardWithBadge({
    required this.trickCard,
    required this.emoji,
    required this.rotation,
    required this.isWinning,
    required this.isTrump,
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    // The card face. `isSelected: isWinning` reuses PlayingCardWidget's
    // gold-border + glow treatment for the winning card.
    final face = PlayingCardWidget(
      suit: suitToString(trickCard.card.suit),
      rank: rankToDisplay(trickCard.card.rank),
      isSelected: isWinning,
      isPlayable: false,
      width: TrickZone._cardW,
      height: TrickZone._cardH,
    );

    // Trump tint removed. Trump suit identity is communicated by the
    // table's trump indicator and by the standard card face (suit symbol
    // + color); the extra gold border around opponent trump cards was
    // reading as a "yellow line / overflow warning" instead of as a
    // trump cue.
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      opacity: isDimmed ? 0.38 : 1.0,
      child: Transform.rotate(
        angle: rotation * 3.14159 / 180,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            face,
          if (emoji.isNotEmpty)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.avatarBg1, AppColors.avatarBg2],
                    ),
                    border: Border.all(
                      color: isWinning ? AppColors.accent : Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      if (isWinning)
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 6,
                        ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child:
                        Text(emoji, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
