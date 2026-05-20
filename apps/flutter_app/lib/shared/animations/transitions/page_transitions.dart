import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// Fade + slight scale (0.95→1) page transition, 300ms.
class GlassFadeTransition extends PageRouteBuilder {
  final Widget page;

  GlassFadeTransition({required this.page})
      : super(
          transitionDuration: AnimationDurations.pageFade,
          reverseTransitionDuration: AnimationDurations.pageFade,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: AnimationCurves.pageFade,
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  fadeAnimation,
                ),
                child: child,
              ),
            );
          },
        );
}

/// Slide from bottom with overshoot bounce, 350ms.
class SlideUpTransition extends PageRouteBuilder {
  final Widget page;

  SlideUpTransition({required this.page})
      : super(
          transitionDuration: AnimationDurations.modalSlide,
          reverseTransitionDuration: AnimationDurations.modalSlide,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AnimationCurves.overshootBounce,
            ));

            return SlideTransition(
              position: slideAnimation,
              child: child,
            );
          },
        );
}

/// Horizontal shared axis transition for tab switches.
class SharedAxisTransition extends PageRouteBuilder {
  final Widget page;

  SharedAxisTransition({required this.page})
      : super(
          transitionDuration: AnimationDurations.pageFade,
          reverseTransitionDuration: AnimationDurations.pageFade,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideIn = Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AnimationCurves.smooth,
            ));

            final fadeIn = Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0, 0.6),
              ),
            );

            return FadeTransition(
              opacity: fadeIn,
              child: SlideTransition(
                position: slideIn,
                child: child,
              ),
            );
          },
        );
}
