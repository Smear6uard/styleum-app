/// Rules Engine for Outfit Pre-Filtering
/// 
/// Philosophy (from Gemini analysis): 
/// "The pre-filter should act as a SAFETY NET, not a stylist."
/// Only remove objectively impossible or dysfunctional combinations.
/// Let Claude Haiku arbitrate subjective style decisions.

import 'package:styleum/models/wardrobe_item.dart';
import 'package:styleum/models/outfit.dart';

/// Rule filtering mode based on wardrobe size
enum RuleMode {
  disabled,    // < 5 items - not enough for generation
  loose,       // 5-9 items - permissive filtering
  normal,      // 10-19 items - standard filtering
  strict,      // 20+ items - enforce diversity
}

/// Color compatibility rules
class ColorRules {
  // Colors that ALWAYS clash (safety net only)
  static const _hardClashes = <String, Set<String>>{
    'neon_green': {'neon_pink', 'neon_orange'},
    'neon_pink': {'neon_green', 'neon_yellow'},
    'neon_orange': {'neon_green', 'neon_purple'},
  };

  // Colors that work with everything (neutrals)
  static const _universalNeutrals = {
    'black', 'white', 'gray', 'grey', 'navy', 'beige', 
    'cream', 'tan', 'brown', 'charcoal', 'ivory', 'khaki',
  };

  /// Check if two colors clash
  /// PERMISSIVE: Only fails on truly egregious combinations
  static bool colorsClash(String color1, String color2) {
    final c1 = color1.toLowerCase().replaceAll(' ', '_');
    final c2 = color2.toLowerCase().replaceAll(' ', '_');
    
    // Neutrals never clash
    if (_universalNeutrals.contains(c1) || _universalNeutrals.contains(c2)) {
      return false;
    }
    
    // Only hard clashes fail
    return _hardClashes[c1]?.contains(c2) == true ||
           _hardClashes[c2]?.contains(c1) == true;
  }

  /// Check if colors are harmonious (for scoring bonus, not filtering)
  static bool colorsHarmonize(String color1, String color2) {
    final c1 = color1.toLowerCase();
    final c2 = color2.toLowerCase();
    
    // Same color family = harmonious
    if (c1 == c2) return true;
    
    // Neutrals harmonize with everything
    if (_universalNeutrals.contains(c1) || _universalNeutrals.contains(c2)) {
      return true;
    }
    
    // Complementary pairs
    const complementary = <String, String>{
      'blue': 'orange',
      'red': 'green',
      'yellow': 'purple',
      'pink': 'green',
      'navy': 'mustard',
    };
    
    return complementary[c1] == c2 || complementary[c2] == c1;
  }
}

/// Formality compatibility rules
class FormalityRules {
  /// Check if items are within acceptable formality range
  /// PERMISSIVE in LOOSE mode, stricter in STRICT mode
  static bool formalitiesCompatible(
    Formality f1, 
    Formality f2, 
    RuleMode mode,
  ) {
    final diff = (f1.index - f2.index).abs();
    
    switch (mode) {
      case RuleMode.disabled:
        return true;
      case RuleMode.loose:
        return diff <= 3; // Allow athleisure + blazer (streetwear trend)
      case RuleMode.normal:
        return diff <= 2;
      case RuleMode.strict:
        return diff <= 1;
    }
  }
}

/// Weather compatibility rules
class WeatherRules {
  /// Check if item is appropriate for weather
  /// This is a HARD rule - safety, not style
  static bool itemAppropriateForWeather(
    WardrobeItem item, 
    WeatherContext weather,
  ) {
    // Seasonality check
    switch (item.seasonality) {
      case Seasonality.summer:
        if (weather.isCold) return false;
        break;
      case Seasonality.winter:
        if (weather.isHot) return false;
        break;
      case Seasonality.spring_fall:
      case Seasonality.all_season:
        // Always appropriate
        break;
    }
    
    // Material-specific rules
    switch (item.material) {
      case Material.wool:
      case Material.fleece:
      case Material.cashmere:
        if (weather.tempFahrenheit > 80) return false;
        break;
      case Material.linen:
        if (weather.tempFahrenheit < 45) return false;
        break;
      default:
        break;
    }
    
    // Category-specific rules (shoes)
    if (item.category == ClothingCategory.shoes) {
      // Open-toed in rain/snow = bad
      if ((weather.isRainy || weather.isSnowy) && 
          item.tags.any((t) => t.contains('open') || t.contains('sandal'))) {
        return false;
      }
    }
    
    return true;
  }
}

/// Pattern mixing rules
class PatternRules {
  /// Check if patterns can be mixed
  /// PERMISSIVE: Solids always work, most patterns work with solids
  static bool patternsCompatible(Pattern p1, Pattern p2, RuleMode mode) {
    // Solid + anything = always OK
    if (p1 == Pattern.solid || p2 == Pattern.solid) {
      return true;
    }
    
    // Same pattern type = risky in strict mode
    if (p1 == p2 && mode == RuleMode.strict) {
      return false;
    }
    
    // In loose/normal mode, let Claude arbitrate pattern mixing
    if (mode != RuleMode.strict) {
      return true;
    }
    
    // Strict mode: only safe pattern combos
    const safeCombos = <Pattern, Set<Pattern>>{
      Pattern.striped: {Pattern.solid, Pattern.polka_dot},
      Pattern.plaid: {Pattern.solid},
      Pattern.floral: {Pattern.solid, Pattern.striped},
      Pattern.geometric: {Pattern.solid},
    };
    
    return safeCombos[p1]?.contains(p2) == true ||
           safeCombos[p2]?.contains(p1) == true;
  }
}

/// Main Rules Engine
class RulesEngine {
  final RuleMode mode;
  final WeatherContext? weather;
  final Set<String> recentlyWornIds;
  final int maxRecentDays;

  const RulesEngine({
    required this.mode,
    this.weather,
    this.recentlyWornIds = const {},
    this.maxRecentDays = 3,
  });

  /// Determine rule mode based on wardrobe size
  static RuleMode getModeForWardrobeSize(int itemCount) {
    if (itemCount < 5) return RuleMode.disabled;
    if (itemCount < 10) return RuleMode.loose;
    if (itemCount < 20) return RuleMode.normal;
    return RuleMode.strict;
  }

  /// Filter a single outfit candidate
  /// Returns null if outfit should be excluded, or outfit with updated score
  OutfitCandidate? filterCandidate(OutfitCandidate candidate) {
    if (mode == RuleMode.disabled) {
      return null; // Not enough items
    }

    int score = 100;
    
    // === HARD RULES (immediate disqualification) ===
    
    // Weather safety (if weather provided)
    if (weather != null) {
      if (!WeatherRules.itemAppropriateForWeather(candidate.top, weather!)) {
        return null;
      }
      if (!WeatherRules.itemAppropriateForWeather(candidate.bottom, weather!)) {
        return null;
      }
      if (!WeatherRules.itemAppropriateForWeather(candidate.shoes, weather!)) {
        return null;
      }
    }
    
    // Recently worn check (in strict mode)
    if (mode == RuleMode.strict) {
      if (recentlyWornIds.contains(candidate.top.id) ||
          recentlyWornIds.contains(candidate.bottom.id)) {
        return null; // Enforce variety
      }
    }
    
    // === SOFT RULES (score deductions) ===
    
    // Color harmony
    if (ColorRules.colorsClash(candidate.top.colorPrimary, candidate.bottom.colorPrimary)) {
      if (mode == RuleMode.strict) return null;
      score -= 20;
    } else if (ColorRules.colorsHarmonize(candidate.top.colorPrimary, candidate.bottom.colorPrimary)) {
      score += 5; // Bonus for harmony
    }
    
    // Formality compatibility
    if (!FormalityRules.formalitiesCompatible(
      candidate.top.formality, 
      candidate.bottom.formality, 
      mode,
    )) {
      if (mode == RuleMode.strict) return null;
      score -= 15;
    }
    
    // Pattern compatibility
    if (!PatternRules.patternsCompatible(
      candidate.top.pattern, 
      candidate.bottom.pattern, 
      mode,
    )) {
      if (mode == RuleMode.strict) return null;
      score -= 10;
    }
    
    // Shoes formality check
    final shoesFormalityDiff = (candidate.shoes.formality.index - 
        candidate.top.formality.index).abs();
    if (shoesFormalityDiff > 2) {
      score -= 10;
    }
    
    // Recently worn penalty (non-strict modes)
    if (mode != RuleMode.strict) {
      if (recentlyWornIds.contains(candidate.top.id)) score -= 15;
      if (recentlyWornIds.contains(candidate.bottom.id)) score -= 15;
    }
    
    // Weather appropriateness bonus
    if (weather != null) {
      if (weather!.needsJacket && candidate.outerwear != null) {
        score += 10;
      }
    }
    
    return candidate.copyWithScore(score.clamp(0, 100));
  }

  /// Filter multiple candidates
  List<OutfitCandidate> filterCandidates(List<OutfitCandidate> candidates) {
    final filtered = <OutfitCandidate>[];
    
    for (final candidate in candidates) {
      final result = filterCandidate(candidate);
      if (result != null) {
        filtered.add(result);
      }
    }
    
    // Sort by rule score (descending)
    filtered.sort((a, b) => b.ruleScore.compareTo(a.ruleScore));
    
    return filtered;
  }
}
