import 'package:flutter/material.dart';
import 'package:styleum/theme/app_animations.dart';

/// Custom page route with easeOutBack slide transition.
///
/// Usage:
/// ```dart
/// Navigator.push(context, AppPageRoute(page: MyScreen()));
/// ```
class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppPageRoute({required this.page})
      : super(
          transitionDuration: const Duration(milliseconds: 350), // 350ms
          reverseTransitionDuration: AppAnimations.slow, // 300ms
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: AppAnimations.easeOutBack, // subtle overshoot
              reverseCurve: AppAnimations.easeOut,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
        );
}

/// Fade + scale transition for modals and dialogs.
class AppModalRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  AppModalRoute({required this.page})
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          transitionDuration: AppAnimations.normal, // 200ms
          reverseTransitionDuration: AppAnimations.fast, // 150ms
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: AppAnimations.easeOut,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}
