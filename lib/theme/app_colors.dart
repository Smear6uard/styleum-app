import 'package:flutter/material.dart';

/// Centralized color palette for Styleum design system.
class AppColors {
  AppColors._();

  // Brand
  static const cherry = Color(0xFFC4515E);
  static const cherryDark = Color(0xFFB34452);
  static const cherryDarker = Color(0xFF9B3C46);

  // Backgrounds
  static const background = Color(0xFFFFFFFF);
  static const inputBackground = Color(0xFFF7F7F7);

  // Text (3 tiers)
  static const textPrimary = Color(0xFF1A1A1A); // headings, body
  static const textSecondary = Color(0xFF4C4C4B); // descriptions
  static const textMuted = Color(0xFF6B7280); // hints, placeholders

  // UI
  static const border = Color(0xFFE5E5E5);
  static const success = Color(0xFF5F7A61);
  static const error = Color(0xFF9B3C46);

  // Shadow base color (espresso)
  static const espresso = Color(0xFF2C1810);
}
