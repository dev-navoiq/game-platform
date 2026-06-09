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

/// Player's hand area using [CardFanAnimation] with [PlayingCardWidget].
///
/// Game-specific behaviour is opt-in via parameters:
///  * [sorter] — per-game sort order (e.g. 29 wants J/9 first within each suit)
///  * [allowQueueWhenNotPlayable] — tapping a card when it isn't your turn
///    queues it to be auto-played when your turn arrives
///  * [flightTargetKey] — when supplied, played cards animate toward this
///    widget's global position instead of just floating upward
///  * [onIllegalTap] — called when the user taps a card not in [validCards];
///    the hand also fires a haptic + shake automatically
class CardHand extends ConsumerStatefulWidget {
  final List<PlayingCard> cards;

  /// Whether tapping a card sends it (false when it's not the local
  /// player's turn AND queueing is off).
  final bool isPlayable;

  /// If supplied, only these cards can be played. Tapping others is treated
  /// as an illegal move (haptic + shake + [onIllegalTap]).
  final Set<PlayingCard>? validCards;

  /// Called when the user confirms a tap on a valid card.
  final void Function(PlayingCard card)? onCardTap;

  /// Called when the user taps a card that isn't in [validCards].
  /// The hand already fires a haptic + shake; this is for screen-level
  /// feedback like a snackbar.
  final void Function(PlayingCard card)? onIllegalTap;

  /// Optional per-game sort. If null, [defaultCardSort] is used.
  final CardSorter? sorter;

  /// If true, an illegal tap can still queue the card to be played later.
  /// Defaults to false — illegal cards are always rejected.
  final bool queueIllegalAsValid;

  /// If true, tapping a card while !isPlayable queues it; CardHand then
  /// auto-plays the queued card the moment [isPlayable] flips true.
  final bool allowQueueWhenNotPlayable;

  /// Target widget the played card flies toward. If null, the played card
  /// just floats upward and fades.
  final GlobalKey? flightTargetKey;

  const CardHand({
    super.key,
    required this.cards,
    this.isPlayable = true,
    this.validCards,
    this.onCardTap,
    this.onIllegalTap,
    this.sorter,
    this.queueIllegalAsValid = false,
    this.allowQueueWhenNotPlayable = true,
    this.flightTargetKey,
  });

  @override
  ConsumerState<CardHand> createState() => _CardHandState();
}

class _CardHandState extends ConsumerState<CardHand> {
  PlayingCard? _playingCard;
  // Used to compute flight offset from the tapped card's global position.
  final Map<PlayingCard, GlobalKey> _cardKeys = {};
  Offset? _flightOffset;

  GlobalKey _keyFor(PlayingCard card) =>
      _cardKeys.putIfAbsent(card, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final sorter = widget.sorter ?? defaultCardSort;
    final displayCards = sorter(widget.cards);
    final selectedCard = ref.watch(selectedCardProvider);
    final queuedCard = ref.watch(queuedCardProvider);
    final selectedIndex =
        selectedCard != null ? displayCards.indexOf(selectedCard) : -1;
    final cardTheme = ref.watch(cardSkinThemeProvider);

    // ── Auto-dispatch a queued card the moment our turn arrives ──
    if (widget.isPlayable &&
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
        selectedIndex: selectedIndex >= 0 ? selectedIndex : null,
        onCardTap: (index) {
          if (index >= displayCards.length) return;
          final card = displayCards[index];
          final canPlay = widget.validCards == null ||
              widget.validCards!.contains(card);

          // Not your turn yet → queue if allowed, otherwise illegal.
          if (!widget.isPlayable) {
            if (widget.allowQueueWhenNotPlayable && canPlay) {
              HapticFeedback.selectionClick();
              ref.read(queuedCardProvider.notifier).state = card;
              ref.read(selectedCardProvider.notifier).state = card;
              return;
            }
            _fireIllegal(card);
            return;
          }

          if (!canPlay) {
            _fireIllegal(card);
            return;
          }

          // Two-tap pattern: first tap selects, second tap plays. If the
          // user already queued this card before their turn, treat the
          // first-after-turn tap as the second tap.
          final preSelected =
              selectedCard == card || queuedCard == card;
          if (preSelected) {
            ref.read(queuedCardProvider.notifier).state = null;
            ref.read(selectedCardProvider.notifier).state = null;
            _animateAndPlay(card);
          } else {
            HapticFeedback.selectionClick();
            ref.read(selectedCardProvider.notifier).state = card;
          }
        },
        cardBuilder: (index) {
          if (index >= displayCards.length) return const SizedBox.shrink();
          final card = displayCards[index];
          final canPlay = widget.validCards == null ||
              widget.validCards!.contains(card);
          final isPlaying = _playingCard == card;
          final isQueued = queuedCard == card;

          final cardWidget = KeyedSubtree(
            key: _keyFor(card),
            child: PlayingCardWidget(
              suit: suitToString(card.suit),
              rank: rankToDisplay(card.rank),
              isSelected: selectedCard == card || isQueued,
              isPlayable: widget.isPlayable && canPlay,
              theme: cardTheme,
            ),
          );

          if (!isPlaying) return cardWidget;

          // Flight animation. If we know the target position, animate
          // toward it; otherwise fall back to the old float-up-and-fade.
          final dx = _flightOffset?.dx ?? 0.0;
          final dy = _flightOffset?.dy ?? -70.0;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) {
              return Transform.translate(
                offset: Offset(dx * t, dy * t),
                child: Transform.scale(
                  scale: 1 - 0.25 * t,
                  child: Opacity(opacity: 1 - 0.55 * t, child: child),
                ),
              );
            },
            child: cardWidget,
          );
        },
      ),
    );
  }

  void _fireIllegal(PlayingCard card) {
    HapticFeedback.heavyImpact();
    widget.onIllegalTap?.call(card);
  }

  /// Compute source → target offset (if a target key is set) and start the
  /// transient "card flying out" animation while [onCardTap] is dispatched.
  void _animateAndPlay(PlayingCard card) {
    final src = _cardKeys[card]?.currentContext?.findRenderObject() as RenderBox?;
    final tgt = widget.flightTargetKey?.currentContext
        ?.findRenderObject() as RenderBox?;
    Offset? offset;
    if (src != null && tgt != null) {
      final srcCenter = src.localToGlobal(src.size.center(Offset.zero));
      final tgtCenter = tgt.localToGlobal(tgt.size.center(Offset.zero));
      offset = tgtCenter - srcCenter;
    }
    setState(() {
      _playingCard = card;
      _flightOffset = offset;
    });
    widget.onCardTap?.call(card);
    Future.delayed(const Duration(milliseconds: 340), () {
      if (!mounted) return;
      setState(() {
        _playingCard = null;
        _flightOffset = null;
      });
    });
  }
}
