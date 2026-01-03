/// Outfit Models
/// Represents both candidate outfits (pre-scoring) and final scored outfits

import 'wardrobe_item.dart';

/// A candidate outfit before AI scoring
class OutfitCandidate {
  final WardrobeItem top;
  final WardrobeItem bottom;
  final WardrobeItem shoes;
  final WardrobeItem? outerwear;
  final WardrobeItem? accessory;
  final int ruleScore; // Deterministic score from rules (0-100)

  const OutfitCandidate({
    required this.top,
    required this.bottom,
    required this.shoes,
    this.outerwear,
    this.accessory,
    this.ruleScore = 100,
  });

  /// Generate compact ID for deduplication
  String get candidateId => '${top.id}_${bottom.id}_${shoes.id}';

  /// Generate text description for Claude Haiku
  String toPromptDescription() {
    final parts = <String>[
      'Top: ${top.toStyleDescription()}',
      'Bottom: ${bottom.toStyleDescription()}',
      'Shoes: ${shoes.toStyleDescription()}',
    ];
    
    if (outerwear != null) {
      parts.add('Outerwear: ${outerwear!.toStyleDescription()}');
    }
    
    if (accessory != null) {
      parts.add('Accessory: ${accessory!.toStyleDescription()}');
    }
    
    return parts.join('\n');
  }

  /// Create a copy with updated rule score
  OutfitCandidate copyWithScore(int newScore) {
    return OutfitCandidate(
      top: top,
      bottom: bottom,
      shoes: shoes,
      outerwear: outerwear,
      accessory: accessory,
      ruleScore: newScore,
    );
  }
}

/// A scored outfit after AI evaluation
class ScoredOutfit {
  final String id;
  final OutfitCandidate candidate;
  final int score;           // Combined rule + AI score (0-100)
  final String whyItWorks;   // AI-generated explanation
  final String? stylingTip;  // Optional bonus tip
  final List<String> vibes;  // Style descriptors ["effortless", "polished"]

  const ScoredOutfit({
    required this.id,
    required this.candidate,
    required this.score,
    required this.whyItWorks,
    this.stylingTip,
    this.vibes = const [],
  });

  WardrobeItem get top => candidate.top;
  WardrobeItem get bottom => candidate.bottom;
  WardrobeItem get shoes => candidate.shoes;
  WardrobeItem? get outerwear => candidate.outerwear;
  WardrobeItem? get accessory => candidate.accessory;

  factory ScoredOutfit.fromJson(Map<String, dynamic> json, OutfitCandidate candidate) {
    return ScoredOutfit(
      id: json['id'] as String? ?? candidate.candidateId,
      candidate: candidate,
      score: json['score'] as int? ?? 75,
      whyItWorks: json['why_it_works'] as String? ?? 'A well-coordinated outfit.',
      stylingTip: json['styling_tip'] as String?,
      vibes: (json['vibes'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'top_id': top.id,
      'bottom_id': bottom.id,
      'shoes_id': shoes.id,
      'outerwear_id': outerwear?.id,
      'accessory_id': accessory?.id,
      'score': score,
      'why_it_works': whyItWorks,
      'styling_tip': stylingTip,
      'vibes': vibes,
    };
  }
}

/// Weather context for outfit generation
class WeatherContext {
  final double tempFahrenheit;
  final String condition; // "sunny", "rainy", "cloudy", "snowy"
  final double humidity;
  final double windMph;
  final String description;

  const WeatherContext({
    required this.tempFahrenheit,
    required this.condition,
    this.humidity = 50,
    this.windMph = 5,
    required this.description,
  });

  bool get isCold => tempFahrenheit < 50;
  bool get isCool => tempFahrenheit >= 50 && tempFahrenheit < 65;
  bool get isMild => tempFahrenheit >= 65 && tempFahrenheit < 75;
  bool get isWarm => tempFahrenheit >= 75 && tempFahrenheit < 85;
  bool get isHot => tempFahrenheit >= 85;
  
  bool get isRainy => condition == 'rainy';
  bool get isSnowy => condition == 'snowy';
  bool get needsJacket => isCold || isCool || isRainy;

  Seasonality get appropriateSeason {
    if (isCold || isSnowy) return Seasonality.winter;
    if (isHot) return Seasonality.summer;
    return Seasonality.all_season;
  }

  factory WeatherContext.fromJson(Map<String, dynamic> json) {
    return WeatherContext(
      tempFahrenheit: (json['temp_f'] as num).toDouble(),
      condition: json['condition'] as String? ?? 'sunny',
      humidity: (json['humidity'] as num?)?.toDouble() ?? 50,
      windMph: (json['wind_mph'] as num?)?.toDouble() ?? 5,
      description: json['description'] as String? ?? 'Clear',
    );
  }

  String toPromptDescription() {
    return 'Weather: ${tempFahrenheit.round()}°F, $description';
  }
}

/// User style preferences
class StylePreferences {
  final String? styleGoal;      // "I want to look polished but approachable"
  final List<String> avoidColors;
  final List<StyleBucket> preferredStyles;
  final int boldnessLevel;      // 1-5 (conservative to bold)
  final String? occasion;       // "work", "date", "casual", etc.
  final String? timeOfDay;      // "morning", "afternoon", "evening"

  const StylePreferences({
    this.styleGoal,
    this.avoidColors = const [],
    this.preferredStyles = const [],
    this.boldnessLevel = 3,
    this.occasion,
    this.timeOfDay,
  });

  factory StylePreferences.fromJson(Map<String, dynamic> json) {
    return StylePreferences(
      styleGoal: json['style_goal'] as String?,
      avoidColors: (json['avoid_colors'] as List<dynamic>?)?.cast<String>() ?? [],
      preferredStyles: (json['preferred_styles'] as List<dynamic>?)
          ?.map((e) => StyleBucket.values.firstWhere(
                (s) => s.name == e,
                orElse: () => StyleBucket.casual,
              ))
          .toList() ?? [],
      boldnessLevel: json['boldness_level'] as int? ?? 3,
      occasion: json['occasion'] as String?,
      timeOfDay: json['time_of_day'] as String?,
    );
  }
}
