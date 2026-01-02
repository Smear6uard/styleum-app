import 'package:flutter/material.dart';

/// Subtle shadow system for Styleum.
/// Premium design uses minimal shadows - prefer borders over shadows.
/// No colored shadows allowed.
class AppShadows {
  AppShadows._();

  /// Card shadow - very subtle depth for cards.
  /// blur: 8, offset: (0, 2), opacity: 4%
  static const card = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  /// Elevated card shadow - for hover/pressed states.
  /// blur: 16, offset: (0, 4), opacity: 8%
  static const cardElevated = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  /// Primary button shadow - subtle depth for CTAs.
  /// blur: 8, offset: (0, 2), opacity: 8%
  static const primaryButton = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  /// Subtle shadow - for small elements.
  /// blur: 4, offset: (0, 1), opacity: 4%
  static const subtle = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 4,
    offset: Offset(0, 1),
  );
}
