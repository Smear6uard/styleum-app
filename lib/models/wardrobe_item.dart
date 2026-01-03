/// Wardrobe Item Model
/// Rich attributes for Claude Haiku to make intelligent outfit decisions
/// As per Gemini analysis: "If the tag says 'Red Shirt', the LLM imagines a generic red shirt"
/// We need: Material, Fit, Pattern, Seasonality for quality "Why it works" explanations

enum ClothingCategory {
  top,
  bottom,
  shoes,
  outerwear,
  accessory,
}

enum StyleBucket {
  casual,
  smart_casual,
  business_casual,
  formal,
  streetwear,
  athleisure,
  bohemian,
  minimalist,
  edgy,
  preppy,
}

enum Material {
  cotton,
  linen,
  silk,
  wool,
  denim,
  leather,
  synthetic,
  knit,
  fleece,
  cashmere,
  velvet,
  corduroy,
  unknown,
}

enum Fit {
  oversized,
  relaxed,
  regular,
  slim,
  cropped,
  baggy,
  tailored,
}

enum Pattern {
  solid,
  striped,
  plaid,
  floral,
  geometric,
  abstract,
  animal_print,
  polka_dot,
  graphic,
}

enum Seasonality {
  summer,
  winter,
  spring_fall,
  all_season,
}

enum Formality {
  very_casual,  // 1 - loungewear, sweats
  casual,       // 2 - jeans, t-shirts
  smart_casual, // 3 - chinos, nice tops
  business,     // 4 - dress pants, blazers
  formal,       // 5 - suits, formal wear
}

class WardrobeItem {
  final String id;
  final String? userId;
  final String? photoUrl;        // Database column: photo_url
  final String? thumbnailUrl;
  final ClothingCategory category;
  final String? subcategory;
  final String? itemName;        // Database column: item_name
  final StyleBucket styleBucket;
  final String colorPrimary;     // Database column: primary_color
  final String? colorSecondary;
  final String? colorHex;
  final Material material;
  final Fit fit;
  final Pattern pattern;
  final Seasonality seasonality;
  final Formality formality;
  final int timesWorn;
  final DateTime? lastWorn;
  final DateTime? createdAt;
  final bool isWeatherAppropriate; // Computed field
  final List<String> tags;       // AI-generated tags
  final List<String>? seasons;   // Database column: seasons
  final List<String>? occasions; // Database column: occasions

  // AI Analysis Fields (from Florence-2 + Gemini pipeline)
  final String? denseCaption;      // Florence-2 detailed description
  final String? ocrText;           // Text read from tags/labels
  final Map<String, double> vibeScores;  // {"cottagecore": 0.85, "minimalist": 0.3}
  final String? eraDetected;       // "1970s", "Y2K", "modern"
  final double? eraConfidence;     // 0.0 - 1.0
  final bool isUnorthodox;         // Defies standard categorization
  final String? unorthodoxDescription;  // Open vocab description
  final String? constructionNotes; // Forensic details
  final bool userVerified;         // User confirmed/edited tags
  final List<double>? embedding;   // 512-dim vector for similarity

  const WardrobeItem({
    required this.id,
    this.userId,
    this.photoUrl,
    this.thumbnailUrl,
    required this.category,
    this.subcategory,
    this.itemName,
    this.styleBucket = StyleBucket.casual,
    this.colorPrimary = 'neutral',
    this.colorSecondary,
    this.colorHex,
    this.material = Material.unknown,
    this.fit = Fit.regular,
    this.pattern = Pattern.solid,
    this.seasonality = Seasonality.all_season,
    this.formality = Formality.casual,
    this.timesWorn = 0,
    this.lastWorn,
    this.createdAt,
    this.isWeatherAppropriate = true,
    this.tags = const [],
    this.seasons,
    this.occasions,
    // AI fields
    this.denseCaption,
    this.ocrText,
    this.vibeScores = const {},
    this.eraDetected,
    this.eraConfidence,
    this.isUnorthodox = false,
    this.unorthodoxDescription,
    this.constructionNotes,
    this.userVerified = false,
    this.embedding,
  });
  
  /// Check if item has been analyzed by AI
  bool get hasAnalysis => denseCaption != null;
  
  /// Check if item is vintage (detected era != modern with high confidence)
  bool get isVintage => 
      eraDetected != null && 
      eraDetected != 'modern' && 
      eraDetected != 'unknown' &&
      (eraConfidence ?? 0) > 0.6;
  
  /// Get primary vibe (highest score)
  String? get primaryVibe {
    if (vibeScores.isEmpty) return null;
    final sorted = vibeScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
  
  /// Get top N vibes
  List<String> topVibes([int n = 3]) {
    if (vibeScores.isEmpty) return [];
    final sorted = vibeScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  /// Generate rich text description for Claude Haiku
  /// Uses AI-generated dense caption when available, falls back to structured description
  String toStyleDescription() {
    // If we have a dense caption from Florence-2, use that (richer)
    if (denseCaption != null && denseCaption!.isNotEmpty) {
      final parts = <String>[denseCaption!];
      
      // Add vibe context if available
      if (vibeScores.isNotEmpty) {
        final topVibe = primaryVibe;
        if (topVibe != null) {
          parts.add('$topVibe vibe');
        }
      }
      
      // Add era if vintage
      if (isVintage && eraDetected != null) {
        parts.add('era: $eraDetected');
      }
      
      return parts.join(', ');
    }
    
    // Fallback to structured description
    final parts = <String>[];
    
    // Category with specifics
    parts.add(_categoryName);
    
    // Color(s)
    if (colorSecondary != null) {
      parts.add('$colorPrimary and $colorSecondary');
    } else {
      parts.add(colorPrimary);
    }
    
    // Material (crucial for texture compatibility)
    if (material != Material.unknown) {
      parts.add(material.name.replaceAll('_', ' '));
    }
    
    // Fit (crucial for silhouette play)
    parts.add('${fit.name.replaceAll('_', ' ')} fit');
    
    // Pattern
    if (pattern != Pattern.solid) {
      parts.add(pattern.name.replaceAll('_', ' '));
    }
    
    // Style bucket
    parts.add('${styleBucket.name.replaceAll('_', ' ')} style');
    
    // Additional tags
    if (tags.isNotEmpty) {
      parts.addAll(tags.take(3)); // Limit to prevent token bloat
    }
    
    return parts.join(', ');
  }

  String get _categoryName {
    switch (category) {
      case ClothingCategory.top:
        return 'top';
      case ClothingCategory.bottom:
        return 'bottom';
      case ClothingCategory.shoes:
        return 'shoes';
      case ClothingCategory.outerwear:
        return 'outerwear';
      case ClothingCategory.accessory:
        return 'accessory';
    }
  }

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      photoUrl: json['photo_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      category: ClothingCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ClothingCategory.top,
      ),
      subcategory: json['subcategory'] as String?,
      itemName: json['item_name'] as String?,
      styleBucket: StyleBucket.values.firstWhere(
        (e) => e.name == json['style_bucket'],
        orElse: () => StyleBucket.casual,
      ),
      colorPrimary: json['primary_color'] as String? ?? 'neutral',
      colorSecondary: json['color_secondary'] as String?,
      colorHex: json['color_hex'] as String?,
      material: Material.values.firstWhere(
        (e) => e.name == json['material'],
        orElse: () => Material.unknown,
      ),
      fit: Fit.values.firstWhere(
        (e) => e.name == json['fit'],
        orElse: () => Fit.regular,
      ),
      pattern: Pattern.values.firstWhere(
        (e) => e.name == json['pattern'],
        orElse: () => Pattern.solid,
      ),
      seasonality: Seasonality.values.firstWhere(
        (e) => e.name == json['seasonality'],
        orElse: () => Seasonality.all_season,
      ),
      formality: Formality.values.firstWhere(
        (e) => e.name == json['formality'],
        orElse: () => Formality.casual,
      ),
      timesWorn: json['times_worn'] as int? ?? 0,
      lastWorn: json['last_worn'] != null
          ? DateTime.parse(json['last_worn'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      seasons: (json['seasons'] as List<dynamic>?)?.cast<String>(),
      occasions: (json['occasions'] as List<dynamic>?)?.cast<String>(),
      // AI analysis fields
      denseCaption: json['dense_caption'] as String?,
      ocrText: json['ocr_text'] as String?,
      vibeScores: (json['vibe_scores'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ?? {},
      eraDetected: json['era_detected'] as String?,
      eraConfidence: (json['era_confidence'] as num?)?.toDouble(),
      isUnorthodox: json['is_unorthodox'] as bool? ?? false,
      unorthodoxDescription: json['unorthodox_description'] as String?,
      constructionNotes: json['construction_notes'] as String?,
      userVerified: json['user_verified'] as bool? ?? false,
      embedding: (json['embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'photo_url': photoUrl,
      'thumbnail_url': thumbnailUrl,
      'category': category.name,
      'subcategory': subcategory,
      'item_name': itemName,
      'style_bucket': styleBucket.name,
      'primary_color': colorPrimary,
      'color_secondary': colorSecondary,
      'color_hex': colorHex,
      'material': material.name,
      'fit': fit.name,
      'pattern': pattern.name,
      'seasonality': seasonality.name,
      'formality': formality.name,
      'times_worn': timesWorn,
      'last_worn': lastWorn?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'tags': tags,
      'seasons': seasons,
      'occasions': occasions,
      // AI analysis fields
      'dense_caption': denseCaption,
      'ocr_text': ocrText,
      'vibe_scores': vibeScores,
      'era_detected': eraDetected,
      'era_confidence': eraConfidence,
      'is_unorthodox': isUnorthodox,
      'unorthodox_description': unorthodoxDescription,
      'construction_notes': constructionNotes,
      'user_verified': userVerified,
      'embedding': embedding,
    };
  }

  WardrobeItem copyWith({
    String? id,
    String? userId,
    String? photoUrl,
    String? thumbnailUrl,
    ClothingCategory? category,
    String? subcategory,
    String? itemName,
    StyleBucket? styleBucket,
    String? colorPrimary,
    String? colorSecondary,
    String? colorHex,
    Material? material,
    Fit? fit,
    Pattern? pattern,
    Seasonality? seasonality,
    Formality? formality,
    int? timesWorn,
    DateTime? lastWorn,
    DateTime? createdAt,
    bool? isWeatherAppropriate,
    List<String>? tags,
    List<String>? seasons,
    List<String>? occasions,
    String? denseCaption,
    String? ocrText,
    Map<String, double>? vibeScores,
    String? eraDetected,
    double? eraConfidence,
    bool? isUnorthodox,
    String? unorthodoxDescription,
    String? constructionNotes,
    bool? userVerified,
    List<double>? embedding,
  }) {
    return WardrobeItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      photoUrl: photoUrl ?? this.photoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      itemName: itemName ?? this.itemName,
      styleBucket: styleBucket ?? this.styleBucket,
      colorPrimary: colorPrimary ?? this.colorPrimary,
      colorSecondary: colorSecondary ?? this.colorSecondary,
      colorHex: colorHex ?? this.colorHex,
      material: material ?? this.material,
      fit: fit ?? this.fit,
      pattern: pattern ?? this.pattern,
      seasonality: seasonality ?? this.seasonality,
      formality: formality ?? this.formality,
      timesWorn: timesWorn ?? this.timesWorn,
      lastWorn: lastWorn ?? this.lastWorn,
      createdAt: createdAt ?? this.createdAt,
      isWeatherAppropriate: isWeatherAppropriate ?? this.isWeatherAppropriate,
      tags: tags ?? this.tags,
      seasons: seasons ?? this.seasons,
      occasions: occasions ?? this.occasions,
      denseCaption: denseCaption ?? this.denseCaption,
      ocrText: ocrText ?? this.ocrText,
      vibeScores: vibeScores ?? this.vibeScores,
      eraDetected: eraDetected ?? this.eraDetected,
      eraConfidence: eraConfidence ?? this.eraConfidence,
      isUnorthodox: isUnorthodox ?? this.isUnorthodox,
      unorthodoxDescription: unorthodoxDescription ?? this.unorthodoxDescription,
      constructionNotes: constructionNotes ?? this.constructionNotes,
      userVerified: userVerified ?? this.userVerified,
      embedding: embedding ?? this.embedding,
    );
  }
}
