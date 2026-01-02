import 'package:flutter/material.dart';

/// Animation timing and easing constants for Styleum.
class AppAnimations {
  AppAnimations._();

  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration page = Duration(milliseconds: 400);

  // Easing curves
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeOutBack = Cubic(0.34, 1.56, 0.64, 1); // subtle overshoot
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve elasticOut = Curves.elasticOut;
}
