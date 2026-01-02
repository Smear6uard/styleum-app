import 'package:flutter/material.dart';

/// Espresso-tinted shadow system for Styleum.
/// All shadows use warm brown (espresso) base color instead of black/gray.
/// Maximum opacity: 15% for espresso, 40% for cherry button glow.
class AppShadows {
  AppShadows._();

  /// Card shadow - standard depth for cards and containers.
  /// blur: 20, offset: (0, 4), opacity: 8%
  static const card = BoxShadow(
    color: Color(0x142C1810),
    blurRadius: 20,
    offset: Offset(0, 4),
  );

  /// Elevated card shadow - for hover/pressed states.
  /// blur: 30, offset: (0, 8), opacity: 12%
  static const cardElevated = BoxShadow(
    color: Color(0x1F2C1810),
    blurRadius: 30,
    offset: Offset(0, 8),
  );

  /// Cherry button glow - for primary CTAs.
  /// blur: 24, offset: (0, 8), opacity: 40%
  static const cherryButton = BoxShadow(
    color: Color(0x66C4515E),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  /// Subtle shadow - for small elements.
  /// blur: 8, offset: (0, 2), opacity: 6%
  static const subtle = BoxShadow(
    color: Color(0x0F2C1810),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
}
