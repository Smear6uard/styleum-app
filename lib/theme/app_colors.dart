import 'package:flutter/material.dart';

/// Centralized color palette for Styleum design system.
/// Premium, restrained, editorial-quality visual language.
///
/// Design Principles:
/// - Black (#111111) = Decision (primary CTAs, important actions)
/// - Slate = Intelligence (selected states, progress, active nav)
/// - White = Canvas (backgrounds, content focus)
/// - Danger = Destructive actions only
class AppColors {
  AppColors._();

  // Brand Accent (Slate) - LIMITED USE
  // Only for: selected states, progress indicators, active nav, toggles
  static const slate = Color(0xFF6F7C86);
  static const slateDark = Color(0xFF3F474F); // Icons, emphasis, score badges

  // Backgrounds
  static const background = Color(0xFFFFFFFF);
  static const inputBackground = Color(0xFFF7F7F7);

  // Text (3 tiers)
  static const textPrimary = Color(0xFF111111); // headings, body, CTAs
  static const textSecondary = Color(0xFF4B5563); // descriptions, secondary content
  static const textMuted = Color(0xFF6B7280); // hints, placeholders, metadata

  // UI
  static const border = Color(0xFFE5E7EB);
  static const filterTagBg = Color(0xFFF3F4F6); // Gray-50 for dismissible tags

  // Danger - Destructive actions ONLY (delete, remove, sign out)
  static const danger = Color(0xFFB42318);

  // Dark Bottom Sheet
  static const darkSheet = Color(0xFF111111);
  static const darkSheetSecondary = Color(0xFF3F474F);
  static const darkSheetMuted = Color(0xFF9CA3AF);

  // Warm neutral overlay (espresso - for soft overlays/backgrounds)
  static const espresso = Color(0xFF2C1810);
}
