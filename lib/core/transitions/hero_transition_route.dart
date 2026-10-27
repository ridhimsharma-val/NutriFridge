import 'package:flutter/material.dart';

/// Design 01 — Hero Transition Route.
///
/// Sourced directly from Design 01 (Hero Transition) in the
/// "Page Transitions" repository (MountainPage).
///
/// Features:
/// - Coordinated 550 ms forward flight / 480 ms reverse flight
/// - Interval-based ease-in-out fade curve (0.20 -> 0.85) allowing the
///   shared-element Hero to lead the visual experience while the destination
///   surfaces fade in seamlessly.
class HeroTransitionRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  HeroTransitionRoute({
    required this.page,
    super.settings,
    super.transitionDuration = const Duration(milliseconds: 550),
    super.reverseTransitionDuration = const Duration(milliseconds: 480),
  }) : super(
          opaque: true,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.20, 0.85, curve: Curves.easeInOut),
                reverseCurve:
                    const Interval(0.25, 0.85, curve: Curves.easeInOut),
              ),
              child: child,
            );
          },
        );
}
