import 'package:flutter/animation.dart';

/// Gameplay-specific animation curves.
///
/// Includes the custom overshoot bounce curve from the design system's
/// `cubic-bezier(0.34, 1.56, 0.64, 1)`.
class AnimationCurves {
  AnimationCurves._();

  // ── Design-system overshoot curve ─────────────────────────────
  /// The standard overshoot bounce used for card selection, modal entry,
  /// and toast entry per `_context.md`.
  static const overshootBounce = Cubic(0.34, 1.56, 0.64, 1);

  // ── Card movements ────────────────────────────────────────────
  static const cardDeal = Curves.easeOutCubic;
  static const cardPlay = Curves.easeOut; // _context.md: ease-out
  static const cardFlip = Curves.easeInOutCubic;
  static const cardSelect = overshootBounce; // _context.md
  static const trickCollect = Curves.easeInQuart;

  // ── Bouncy effects ────────────────────────────────────────────
  static const bounce = Curves.elasticOut;
  static const gentleBounce = Curves.easeOutBack;

  // ── Smooth transitions ────────────────────────────────────────
  static const smooth = Curves.easeInOutCubic;
  static const smoothIn = Curves.easeInCubic;
  static const smoothOut = Curves.easeOutCubic;

  // ── Snappy ────────────────────────────────────────────────────
  static const snappy = Curves.easeOutQuart;

  // ── UI-specific ───────────────────────────────────────────────
  static const modalEntry = overshootBounce; // _context.md: 350ms
  static const toastEntry = overshootBounce; // _context.md: 400ms
  static const pageFade = Curves.easeInOutCubic;
}
