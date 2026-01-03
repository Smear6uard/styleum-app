/// Anchor-Based Candidate Generator
/// 
/// From Gemini analysis:
/// "Instead of brute-force generation O(N³), implement Anchor-Based Generator:
/// 1. Select an Anchor (Hero Item) based on weather
/// 2. Filter for compatible items FIRST
/// 3. Cross-product only the subset
/// Result: 600,000 → 200 combinations"
///
/// This ensures "instant" performance regardless of wardrobe size.

import 'dart:math';
import 'package:styleum/models/wardrobe_item.dart';
import 'package:styleum/models/outfit.dart';
import 'rules_engine.dart';

/// Configuration for candidate generation
class GenerationConfig {
  final int maxCandidates;      // Max candidates to generate
  final int maxAnchors;         // Max anchor items to try
  final bool prioritizeUnworn;  // Prefer items worn less often
  final bool enableOuterwear;   // Include outerwear layer
  final bool enableAccessories; // Include accessory layer

  const GenerationConfig({
    this.maxCandidates = 50,
    this.maxAnchors = 5,
    this.prioritizeUnworn = true,
    this.enableOuterwear = false,
    this.enableAccessories = false,
  });
}

/// Anchor-based candidate generator
class CandidateGenerator {
  final Random _random = Random();

  /// Generate outfit candidates using anchor-based approach
  /// 
  /// Algorithm:
  /// 1. Select weather-appropriate "anchor" tops
  /// 2. For each anchor, find compatible bottoms (formality + color)
  /// 3. For each top-bottom pair, find compatible shoes
  /// 4. Optionally add outerwear/accessories
  /// 5. Apply rule-based filtering
  List<OutfitCandidate> generateCandidates({
    required List<WardrobeItem> wardrobe,
    required WeatherContext? weather,
    required RulesEngine rulesEngine,
    required GenerationConfig config,
    StylePreferences? preferences,
  }) {
    // Categorize wardrobe
    final tops = wardrobe.where((i) => i.category == ClothingCategory.top).toList();
    final bottoms = wardrobe.where((i) => i.category == ClothingCategory.bottom).toList();
    final shoes = wardrobe.where((i) => i.category == ClothingCategory.shoes).toList();
    final outerwear = wardrobe.where((i) => i.category == ClothingCategory.outerwear).toList();
    final accessories = wardrobe.where((i) => i.category == ClothingCategory.accessory).toList();

    // Check minimum requirements
    if (tops.isEmpty || bottoms.isEmpty || shoes.isEmpty) {
      return [];
    }

    // Step 1: Select anchor tops (weather-appropriate, varied)
    final anchorTops = _selectAnchors(
      items: tops,
      weather: weather,
      preferences: preferences,
      maxAnchors: config.maxAnchors,
      prioritizeUnworn: config.prioritizeUnworn,
    );

    if (anchorTops.isEmpty) {
      // Fallback: use any tops if none are weather-appropriate
      anchorTops.addAll(tops.take(config.maxAnchors));
    }

    final candidates = <OutfitCandidate>[];
    final seenCombos = <String>{};

    // Step 2-3: For each anchor, build compatible outfits
    for (final anchor in anchorTops) {
      // Find compatible bottoms
      final compatibleBottoms = _findCompatibleBottoms(
        anchor: anchor,
        bottoms: bottoms,
        weather: weather,
        rulesEngine: rulesEngine,
        preferences: preferences,
      );

      for (final bottom in compatibleBottoms) {
        // Find compatible shoes
        final compatibleShoes = _findCompatibleShoes(
          top: anchor,
          bottom: bottom,
          shoes: shoes,
          weather: weather,
          preferences: preferences,
        );

        for (final shoe in compatibleShoes) {
          // Create base candidate
          final candidateId = '${anchor.id}_${bottom.id}_${shoe.id}';
          if (seenCombos.contains(candidateId)) continue;
          seenCombos.add(candidateId);

          WardrobeItem? selectedOuterwear;
          WardrobeItem? selectedAccessory;

          // Step 4: Add outerwear if needed
          if (config.enableOuterwear && weather?.needsJacket == true && outerwear.isNotEmpty) {
            selectedOuterwear = _selectOuterwear(
              outfit: (anchor, bottom, shoe),
              outerwear: outerwear,
              weather: weather,
            );
          }

          // Add accessory for variety
          if (config.enableAccessories && accessories.isNotEmpty && _random.nextDouble() > 0.5) {
            selectedAccessory = _selectAccessory(
              outfit: (anchor, bottom, shoe),
              accessories: accessories,
            );
          }

          final candidate = OutfitCandidate(
            top: anchor,
            bottom: bottom,
            shoes: shoe,
            outerwear: selectedOuterwear,
            accessory: selectedAccessory,
          );

          candidates.add(candidate);

          // Early exit if we have enough candidates
          if (candidates.length >= config.maxCandidates) {
            break;
          }
        }
        if (candidates.length >= config.maxCandidates) break;
      }
      if (candidates.length >= config.maxCandidates) break;
    }

    // Step 5: Apply rules engine filtering
    return rulesEngine.filterCandidates(candidates);
  }

  /// Select anchor items (tops) for generation
  List<WardrobeItem> _selectAnchors({
    required List<WardrobeItem> items,
    required WeatherContext? weather,
    required StylePreferences? preferences,
    required int maxAnchors,
    required bool prioritizeUnworn,
  }) {
    var filtered = items.toList();

    // Filter by weather appropriateness
    if (weather != null) {
      filtered = filtered.where((item) {
        return WeatherRules.itemAppropriateForWeather(item, weather);
      }).toList();
    }

    // Filter by occasion if specified
    if (preferences?.occasion != null) {
      final targetFormality = _occasionToFormality(preferences!.occasion!);
      filtered = filtered.where((item) {
        final diff = (item.formality.index - targetFormality.index).abs();
        return diff <= 1;
      }).toList();
    }

    // Sort by priority
    if (prioritizeUnworn) {
      filtered.sort((a, b) {
        // Primary: times worn (ascending - prefer less worn)
        final wornCompare = a.timesWorn.compareTo(b.timesWorn);
        if (wornCompare != 0) return wornCompare;
        
        // Secondary: last worn (ascending - prefer older)
        if (a.lastWorn == null && b.lastWorn != null) return -1;
        if (a.lastWorn != null && b.lastWorn == null) return 1;
        if (a.lastWorn != null && b.lastWorn != null) {
          return a.lastWorn!.compareTo(b.lastWorn!);
        }
        
        return 0;
      });
    } else {
      // Random shuffle for variety
      filtered.shuffle(_random);
    }

    // Ensure style variety in anchors
    return _ensureStyleVariety(filtered, maxAnchors);
  }

  /// Find bottoms compatible with anchor top
  List<WardrobeItem> _findCompatibleBottoms({
    required WardrobeItem anchor,
    required List<WardrobeItem> bottoms,
    required WeatherContext? weather,
    required RulesEngine rulesEngine,
    required StylePreferences? preferences,
  }) {
    var compatible = bottoms.toList();

    // Weather filter
    if (weather != null) {
      compatible = compatible.where((b) {
        return WeatherRules.itemAppropriateForWeather(b, weather);
      }).toList();
    }

    // Formality filter (within 2 levels)
    compatible = compatible.where((b) {
      final diff = (b.formality.index - anchor.formality.index).abs();
      return diff <= 2;
    }).toList();

    // Color filter (no hard clashes)
    compatible = compatible.where((b) {
      return !ColorRules.colorsClash(anchor.colorPrimary, b.colorPrimary);
    }).toList();

    // Avoid colors user dislikes
    if (preferences != null && preferences.avoidColors.isNotEmpty) {
      compatible = compatible.where((b) {
        return !preferences.avoidColors.any((c) => 
          b.colorPrimary.toLowerCase().contains(c.toLowerCase()));
      }).toList();
    }

    // Sort by compatibility score
    compatible.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;

      // Bonus for color harmony
      if (ColorRules.colorsHarmonize(anchor.colorPrimary, a.colorPrimary)) scoreA += 10;
      if (ColorRules.colorsHarmonize(anchor.colorPrimary, b.colorPrimary)) scoreB += 10;

      // Bonus for similar style
      if (a.styleBucket == anchor.styleBucket) scoreA += 5;
      if (b.styleBucket == anchor.styleBucket) scoreB += 5;

      // Prefer unworn
      scoreA -= a.timesWorn;
      scoreB -= b.timesWorn;

      return scoreB.compareTo(scoreA);
    });

    // Limit results
    return compatible.take(10).toList();
  }

  /// Find shoes compatible with top-bottom combo
  List<WardrobeItem> _findCompatibleShoes({
    required WardrobeItem top,
    required WardrobeItem bottom,
    required List<WardrobeItem> shoes,
    required WeatherContext? weather,
    required StylePreferences? preferences,
  }) {
    var compatible = shoes.toList();

    // Weather filter
    if (weather != null) {
      compatible = compatible.where((s) {
        return WeatherRules.itemAppropriateForWeather(s, weather);
      }).toList();
    }

    // Formality filter (shoes can be +/- 2 from outfit average)
    final outfitFormality = ((top.formality.index + bottom.formality.index) / 2).round();
    compatible = compatible.where((s) {
      final diff = (s.formality.index - outfitFormality).abs();
      return diff <= 2;
    }).toList();

    // Sort by compatibility
    compatible.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;

      // Prefer closer formality
      scoreA -= (a.formality.index - outfitFormality).abs();
      scoreB -= (b.formality.index - outfitFormality).abs();

      // Prefer unworn
      scoreA -= a.timesWorn;
      scoreB -= b.timesWorn;

      return scoreB.compareTo(scoreA);
    });

    return compatible.take(5).toList();
  }

  /// Select outerwear for the outfit
  WardrobeItem? _selectOuterwear({
    required (WardrobeItem, WardrobeItem, WardrobeItem) outfit,
    required List<WardrobeItem> outerwear,
    required WeatherContext? weather,
  }) {
    if (outerwear.isEmpty) return null;

    final (top, bottom, _) = outfit;

    // Filter by weather and formality
    var compatible = outerwear.where((o) {
      if (weather != null && !WeatherRules.itemAppropriateForWeather(o, weather)) {
        return false;
      }
      final diff = (o.formality.index - top.formality.index).abs();
      return diff <= 2;
    }).toList();

    if (compatible.isEmpty) return null;

    // Sort by harmony with outfit
    compatible.sort((a, b) {
      int scoreA = 0;
      int scoreB = 0;

      if (ColorRules.colorsHarmonize(top.colorPrimary, a.colorPrimary)) scoreA += 5;
      if (ColorRules.colorsHarmonize(top.colorPrimary, b.colorPrimary)) scoreB += 5;

      return scoreB.compareTo(scoreA);
    });

    return compatible.first;
  }

  /// Select accessory for the outfit
  WardrobeItem? _selectAccessory({
    required (WardrobeItem, WardrobeItem, WardrobeItem) outfit,
    required List<WardrobeItem> accessories,
  }) {
    if (accessories.isEmpty) return null;

    final (top, _, _) = outfit;

    // Prefer accessories that complement the top color
    final complementary = accessories.where((a) {
      return ColorRules.colorsHarmonize(top.colorPrimary, a.colorPrimary);
    }).toList();

    if (complementary.isNotEmpty) {
      return complementary[_random.nextInt(complementary.length)];
    }

    return accessories[_random.nextInt(accessories.length)];
  }

  /// Ensure variety in selected items
  List<WardrobeItem> _ensureStyleVariety(List<WardrobeItem> items, int count) {
    if (items.length <= count) return items;

    final selected = <WardrobeItem>[];
    final usedStyles = <StyleBucket>{};
    final usedColors = <String>{};

    // First pass: prioritize variety
    for (final item in items) {
      if (selected.length >= count) break;

      // Accept if new style or new color
      if (!usedStyles.contains(item.styleBucket) || 
          !usedColors.contains(item.colorPrimary)) {
        selected.add(item);
        usedStyles.add(item.styleBucket);
        usedColors.add(item.colorPrimary);
      }
    }

    // Fill remaining slots
    for (final item in items) {
      if (selected.length >= count) break;
      if (!selected.contains(item)) {
        selected.add(item);
      }
    }

    return selected;
  }

  /// Map occasion to formality level
  Formality _occasionToFormality(String occasion) {
    switch (occasion.toLowerCase()) {
      case 'work':
      case 'office':
      case 'meeting':
        return Formality.business;
      case 'date':
      case 'dinner':
        return Formality.smart_casual;
      case 'casual':
      case 'weekend':
      case 'brunch':
        return Formality.casual;
      case 'formal':
      case 'wedding':
      case 'event':
        return Formality.formal;
      case 'gym':
      case 'workout':
      case 'lounge':
        return Formality.very_casual;
      default:
        return Formality.casual;
    }
  }
}
