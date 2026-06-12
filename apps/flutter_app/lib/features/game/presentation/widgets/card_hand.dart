import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

import '../../../../core/di/skin_theme_providers.dart';
import '../../../../shared/animations/cards/card_fan_animation.dart';
import '../../../../shared/widgets/playing_card_widget.dart';
import '../../providers/game_session_providers.dart';
import 'card_sort.dart';

/// Maps a [Rank] enum to its display string for [PlayingCardWidget].
String rankToDisplay(Rank rank) {
  switch (rank) {
    case Rank.ace:
      return 'A';
    case Rank.king:
      return 'K';
    case Rank.queen:
      return 'Q';
    case Rank.jack:
      return 'J';
    case Rank.ten:
      return '10';
    case Rank.nine:
      return '9';
    case Rank.eight:
      return '8';
    case Rank.seven:
      return '7';
    case Rank.six:
      return '6';
    case Rank.five:
      return '5';
    case Rank.four:
      return '4';
    case Rank.three:
      return '3';
    case Rank.two:
      return '2';
  }
}

/// Maps a [Suit] to the string expected by [PlayingCardWidget].
String suitToString(Suit suit) => suit.name;

/// Backwards-compatible alias for the old global sort. New callers should
/// pass a [CardSorter] into [CardHand] instead.
List<PlayingCard> sortCardsForDisplay(List<PlayingCard> cards) =>
    defaultCardSort(cards);

/// How CardHand reacts to a card tap.
enum CardHandMode {
  /// Trick games (Bridge, 29, Oh Hell, Hearts, Spades): a single tap on a
  /// playable card commits the play immediately. Tapping when it isn't your
  /// turn queues the card to auto-play when your turn arrives.
  tapToPlay,

  /// Board games that need a second target (Sequence): tap sets
  /// [selectedCardProvider] and lifts the card; the parent screen reads the
  /// selected card when the user taps a board cell to commit.
  tapToSelect,
}

/// Player's hand strip.
///
/// In [CardHandMode.tapToPlay] (the default), a single tap on a playable card
/// fires [onCardTap] and starts the flight animation in the same frame — no
/// select-then-commit step. Illegal taps bounce (haptic + [onIllegalTap]).
///
/// In [CardHandMode.tapToSelect], a tap just updates [selectedCardProvider];
/// the screen calls into the engine separately.
class CardHand extends ConsumerStatefulWidget {
  final List<PlayingCard> cards;

  /// Whether tapping a card sends it (false when it's not the local player's
  /// turn AND queueing is off, or in [CardHandMode.tapToSelect]).
  final bool isPlayable;

  /// If supplied, only these cards can be played. Tapping others is treated
  /// as an illegal move (haptic + [onIllegalTap]).
  final Set<PlayingCard>? validCards;

  /// Called when the user commits a play on a valid card (tap-to-play mode).
  /// In tap-to-select mode this fires too for callers that need to know
  /// about taps; selection state lives on [selectedCardProvider].
  final void Function(PlayingCard card)? onCardTap;

  /// Called when the user taps a card that isn't in [validCards].
  /// The hand already fires a haptic; this is for snackbar-level feedback.
  final void Function(PlayingCard card)? onIllegalTap;

  /// Optional per-game sort. If null, [defaultCardSort] is used.
  final CardSorter? sorter;

  /// If true, tapping a playable card while !isPlayable queues it; CardHand
  /// then auto-plays the queued card the moment [isPlayable] flips true.
  /// Only meaningful in [CardHandMode.tapToPlay].
  final bool allowQueueWhenNotPlayable;

  /// Target widget the played card flies toward. If null, the played card
  /// just floats upward and fades.
  final GlobalKey? flightTargetKey;

  /// Local player's emoji. When provided, the local card's flight animation
  /// renders the avatar badge from the start of the flight — without it,
  /// the badge "pops in" as a separate visual event when the trick zone
  /// takes over from the flight.
  final String? localEmoji;

  final CardHandMode mode;

  const CardHand({
    super.key,
    required this.cards,
    this.isPlayable = true,
    this.validCards,
    this.onCardTap,
    this.onIllegalTap,
    this.sorter,
    this.allowQueueWhenNotPlayable = true,
    this.flightTargetKey,
    this.localEmoji,
    this.mode = CardHandMode.tapToPlay,
  });

  @override
  ConsumerState<CardHand> createState() => _CardHandState();
}

class _CardHandState extends ConsumerState<CardHand> {
  PlayingCard? _playingCard;
  // Per-card GlobalKey for computing flight source position.
  final Map<PlayingCard, GlobalKey> _cardKeys = {};
  Offset? _flightOffset;
  // Safety timer that clears a stuck in-flight overlay if the server
  // never confirms the play. Held so it can be cancelled on dispose.
  Timer? _flightTimeoutTimer;

  GlobalKey _keyFor(PlayingCard card) =>
      _cardKeys.putIfAbsent(card, () => GlobalKey());

  @override
  void didUpdateWidget(covariant CardHand old) {
    super.didUpdateWidget(old);
    // Round boundary (empty → full, or new hand bigger than old) wipes any
    // mid-flight state and stale GlobalKey cache so the new round doesn't
    // reuse a key attached to a torn-down PlayingCardWidget.
    final newRound = (old.cards.isNotEmpty &&
            widget.cards.isNotEmpty &&
            old.cards.length < widget.cards.length) ||
        (old.cards.isEmpty && widget.cards.isNotEmpty);
    if (newRound) {
      _playingCard = null;
      _flightOffset = null;
      _cardKeys.clear();
    }
    // Server-confirmed play: the card we flew is no longer in widget.cards,
    // so stop rendering the in-flight overlay. Without this, the flight
    // would clear after a fixed timer and could briefly "bounce back" if
    // the server roundtrip was slow.
    if (_playingCard != null && !widget.cards.contains(_playingCard)) {
      _playingCard = null;
      _flightOffset = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorter = widget.sorter ?? defaultCardSort;
    final displayCards = sorter(widget.cards);
    final selectedCard = ref.watch(selectedCardProvider);
    final queuedCard = ref.watch(queuedCardProvider);
    final cardTheme = ref.watch(cardSkinThemeProvider);

    // Which card (if any) should render in the "lifted" position. In
    // tap-to-play mode this is the queued card (tapped before our turn);
    // in tap-to-select mode it's the explicitly selected card.
    final liftedCard = widget.mode == CardHandMode.tapToSelect
        ? selectedCard
        : queuedCard;
    final liftedIndex =
        liftedCard != null ? displayCards.indexOf(liftedCard) : -1;

    // ── Auto-dispatch a queued card the moment our turn arrives ──
    if (widget.mode == CardHandMode.tapToPlay &&
        widget.isPlayable &&
        queuedCard != null &&
        widget.cards.contains(queuedCard)) {
      final isLegal = widget.validCards == null ||
          widget.validCards!.contains(queuedCard);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(queuedCardProvider) != queuedCard) return;
        if (isLegal) {
          _animateAndPlay(queuedCard);
          ref.read(queuedCardProvider.notifier).state = null;
        } else {
          // Queued card became illegal once the trick context resolved
          // (e.g. must-follow-suit). Drop the queue and tell the user.
          ref.read(queuedCardProvider.notifier).state = null;
          _fireIllegal(queuedCard);
        }
      });
    }

    // ── Clear stale queued card if it's no longer in hand ──
    if (queuedCard != null && !widget.cards.contains(queuedCard)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(queuedCardProvider.notifier).state = null;
      });
    }

    return Container(
      key: const Key('player-hand'),
      child: CardFanAnimation(
        cardCount: displayCards.length,
        selectedIndex: liftedIndex >= 0 ? liftedIndex : null,
        onCardTap: (index) {
          if (index >= displayCards.length) return;
          final card = displayCards[index];
          _onTap(card);
        },
        cardBuilder: (index) {
          if (index >= displayCards.length) return const SizedBox.shrink();
          final card = displayCards[index];
          final canPlay = widget.validCards == null ||
              widget.validCards!.contains(card);
          final isPlaying = _playingCard == card;
          final isLifted = liftedCard == card;

          final cardWidget = KeyedSubtree(
            key: _keyFor(card),
            child: PlayingCardWidget(
              suit: suitToString(card.suit),
              rank: rankToDisplay(card.rank),
              isSelected: isLifted,
              isPlayable: widget.isPlayable && canPlay,
              theme: cardTheme,
              width: CardFanAnimation.cardWidth,
              height: CardFanAnimation.cardHeight,
            ),
          );

          if (!isPlaying) return cardWidget;

          // Two-phase flight: 25% of the duration scales up in place
          // (1.0 → 1.15) so the commit registers visually; remaining 75%
          // translates to the trick zone. `_playingCard` is held until
          // didUpdateWidget sees the card removed from widget.cards (server
          // confirmed) so the card never bounces back into the hand.
          //
          // The card carries the local player's avatar badge during the
          // flight (when [localEmoji] is provided). Without this the trick
          // zone "adds" the badge after the flight lands, producing a
          // visible pop-in jitter at touch-down.
          final dx = _flightOffset?.dx ?? 0.0;
          final dy = _flightOffset?.dy ?? -70.0;
          final emoji = widget.localEmoji;
          final flightCard = emoji == null
              ? cardWidget
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    cardWidget,
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
                              colors: [
                                Color(0xFF6B4A30),
                                Color(0xFF8A6342),
                              ],
                            ),
                            border:
                                Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 460),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) {
              // Translate over the full duration so the path is one smooth
              // motion.
              final translateT = t;
              // Scale follows a bell curve: 1.0 → ~1.10 at t=0.5 → 1.0 at
              // t=1.0. The card lands at exactly 1.0× so the trick zone
              // can take over without a "snap smaller" jerk.
              final scale = 1.0 + 0.10 * (1 - (2 * t - 1).abs());
              return Transform.translate(
                offset: Offset(dx * translateT, dy * translateT),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: flightCard,
          );
        },
      ),
    );
  }

  void _onTap(PlayingCard card) {
    final canPlay =
        widget.validCards == null || widget.validCards!.contains(card);

    // ── Tap-to-select mode (Sequence) — selection only, no flight ──
    if (widget.mode == CardHandMode.tapToSelect) {
      if (!widget.isPlayable) {
        _fireIllegal(card);
        return;
      }
      if (!canPlay) {
        _fireIllegal(card);
        return;
      }
      HapticFeedback.selectionClick();
      ref.read(selectedCardProvider.notifier).state = card;
      widget.onCardTap?.call(card);
      return;
    }

    // ── Tap-to-play mode (trick games) — single tap commits ──
    if (!widget.isPlayable) {
      if (widget.allowQueueWhenNotPlayable && canPlay) {
        HapticFeedback.selectionClick();
        ref.read(queuedCardProvider.notifier).state = card;
        return;
      }
      _fireIllegal(card);
      return;
    }
    if (!canPlay) {
      _fireIllegal(card);
      return;
    }

    // Clear any prior queue/select state and fire immediately.
    if (ref.read(queuedCardProvider) != null) {
      ref.read(queuedCardProvider.notifier).state = null;
    }
    _animateAndPlay(card);
  }

  void _fireIllegal(PlayingCard card) {
    HapticFeedback.heavyImpact();
    widget.onIllegalTap?.call(card);
  }

  /// Compute source → target offset (if a target key is set) and start the
  /// transient "card flying out" overlay while [onCardTap] is dispatched.
  /// `_playingCard` is held until the server confirms (didUpdateWidget sees
  /// the card removed from widget.cards). A 3-second safety timer covers
  /// the case where the server never confirms.
  void _animateAndPlay(PlayingCard card) {
    HapticFeedback.mediumImpact();
    final src =
        _cardKeys[card]?.currentContext?.findRenderObject() as RenderBox?;
    final tgt = widget.flightTargetKey?.currentContext
        ?.findRenderObject() as RenderBox?;
    Offset? offset;
    if (src != null && tgt != null) {
      final srcCenter = src.localToGlobal(src.size.center(Offset.zero));
      // Bias the target away from the trick-zone *center* and onto the
      // local player's actual seat slot (south of center, at the same kR
      // radius used by TrickZone's vector layout). Without this bias the
      // card flies to the centre, then TrickZone's AnimatedPositioned
      // slides it the rest of the way south — which the user perceives as
      // "the card hangs in space and then settles". Keeping the value in
      // sync with TrickZone.kR (56) is a hand-maintained coupling for now.
      const localSlotBias = Offset(0, 56);
      final tgtCenter = tgt.localToGlobal(tgt.size.center(Offset.zero)) +
          localSlotBias;
      offset = tgtCenter - srcCenter;
    }
    setState(() {
      _playingCard = card;
      _flightOffset = offset;
    });
    widget.onCardTap?.call(card);
    _flightTimeoutTimer?.cancel();
    _flightTimeoutTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_playingCard != card) return;
      setState(() {
        _playingCard = null;
        _flightOffset = null;
      });
    });
  }

  @override
  void dispose() {
    _flightTimeoutTimer?.cancel();
    super.dispose();
  }
}
