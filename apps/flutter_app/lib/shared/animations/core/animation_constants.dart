/// Gameplay-specific animation durations.
///
/// Values are aligned with the design system in `_context.md`.
/// For UI widget transitions (hover, focus, etc.), see [GlassTokens].
class AnimationDurations {
  AnimationDurations._();

  // ── Card animations ───────────────────────────────────────────
  static const cardDeal = Duration(milliseconds: 300);
  static const cardDealDelay = Duration(milliseconds: 80);
  static const cardPlay = Duration(milliseconds: 300); // _context.md: 300ms
  static const cardFlip = Duration(milliseconds: 400);
  static const cardSelect = Duration(milliseconds: 220); // _context.md: 220ms
  static const cardEntryStagger = Duration(milliseconds: 60);
  static const trickCollect = Duration(milliseconds: 500);
  static const shuffle = Duration(milliseconds: 800);

  // ── Gameplay ──────────────────────────────────────────────────
  static const turnIndicator = Duration(milliseconds: 1200); // _context.md: 1200ms
  static const bidCounter = Duration(milliseconds: 200);
  static const trumpReveal = Duration(milliseconds: 800);
  static const scoreUpdate = Duration(milliseconds: 400);

  // ── Celebrations ──────────────────────────────────────────────
  static const confetti = Duration(seconds: 3);
  static const fireworks = Duration(seconds: 2);
  static const trophy = Duration(milliseconds: 1200);

  // ── UI ────────────────────────────────────────────────────────
  static const pageFade = Duration(milliseconds: 300);

  /// Route-level navigation transition. Deliberately shorter than [pageFade]
  /// so moving between screens (home → lobby → room → game) feels snappy
  /// rather than a slow ~300ms Material slide.
  static const navTransition = Duration(milliseconds: 200);
  static const modalSlide = Duration(milliseconds: 350); // _context.md: 350ms
  static const listItem = Duration(milliseconds: 250);
  static const listItemStagger = Duration(milliseconds: 60);
  static const microInteraction = Duration(milliseconds: 150);

  // ── Social ────────────────────────────────────────────────────
  static const emojiFloat = Duration(milliseconds: 1400); // _context.md: 1400ms
  static const toastEntry = Duration(milliseconds: 400); // _context.md: 400ms
  static const chatBubbleEnter = Duration(milliseconds: 250);
  static const chatBubbleExit = Duration(milliseconds: 300);
  static const avatarReaction = Duration(milliseconds: 600);
}
