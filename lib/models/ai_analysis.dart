// AI Analysis Models
//
// Rich structured data from the AI tagging pipeline:
// - Florence-2 dense captions + OCR
// - Gemini era/vibe/construction analysis
// - Vector-based vibe scores
// - User style vector

/// Era detection result from forensic analysis
class EraAnalysis {
  final String detected;
  final double confidence;
  final String reasoning;

  const EraAnalysis({
    required this.detected,
    required this.confidence,
    required this.reasoning,
  });

  bool get isVintage => 
      detected != 'modern' && detected != 'unknown' && confidence > 0.6;

  String get displayName {
    switch (detected) {
      case '1950s': return '50s';
      case '1960s': return '60s';
      case '1970s': return '70s';
      case '1980s': return '80s';
      case '1990s': return '90s';
      case 'Y2K': return 'Y2K';
      case '2010s': return '2010s';
      case 'modern': return 'Modern';
      default: return detected;
    }
  }

  factory EraAnalysis.fromJson(Map<String, dynamic> json) {
    return EraAnalysis(
      detected: json['detected'] as String? ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reasoning: json['reasoning'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'detected': detected,
    'confidence': confidence,
    'reasoning': reasoning,
  };
}

/// Construction/quality analysis
class ConstructionAnalysis {
  final String materialGuess;
  final List<String> qualitySignals;
  final List<String> notableDetails;

  const ConstructionAnalysis({
    required this.materialGuess,
    required this.qualitySignals,
    required this.notableDetails,
  });

  bool get hasQualityIndicators => qualitySignals.isNotEmpty;

  factory ConstructionAnalysis.fromJson(Map<String, dynamic> json) {
    return ConstructionAnalysis(
      materialGuess: json['material_guess'] as String? ?? 'unknown',
      qualitySignals: (json['quality_signals'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      notableDetails: (json['notable_details'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'material_guess': materialGuess,
    'quality_signals': qualitySignals,
    'notable_details': notableDetails,
  };
}

/// Complete AI analysis result for an item
class AIAnalysisResult {
  final String denseCaption;
  final String? ocrText;
  final EraAnalysis era;
  final Map<String, double> vibeScores;
  final ConstructionAnalysis construction;
  final bool isUnorthodox;
  final String? unorthodoxDescription;
  final List<String> tags;
  final String styleBucket;
  final String formality;
  final String seasonality;
  final DateTime analyzedAt;

  const AIAnalysisResult({
    required this.denseCaption,
    this.ocrText,
    required this.era,
    required this.vibeScores,
    required this.construction,
    required this.isUnorthodox,
    this.unorthodoxDescription,
    required this.tags,
    required this.styleBucket,
    required this.formality,
    required this.seasonality,
    required this.analyzedAt,
  });

  /// Get top vibes sorted by confidence
  List<MapEntry<String, double>> get topVibes {
    final sorted = vibeScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }

  /// Get primary vibe (highest confidence)
  String? get primaryVibe {
    if (vibeScores.isEmpty) return null;
    return topVibes.first.key;
  }

  /// Check if item has a specific vibe above threshold
  bool hasVibe(String vibe, {double threshold = 0.5}) {
    return (vibeScores[vibe] ?? 0.0) >= threshold;
  }

  /// Human-readable vibe string
  String get vibeDescription {
    final top = topVibes;
    if (top.isEmpty) return 'Unknown vibe';
    if (top.length == 1) return _formatVibeName(top.first.key);
    return '${_formatVibeName(top[0].key)} with ${_formatVibeName(top[1].key)} vibes';
  }

  String _formatVibeName(String vibe) {
    return vibe
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AIAnalysisResult(
      denseCaption: json['dense_caption'] as String? ?? '',
      ocrText: json['ocr_text'] as String?,
      era: EraAnalysis.fromJson(json['era'] as Map<String, dynamic>? ?? {}),
      vibeScores: (json['vibes'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ?? {},
      construction: ConstructionAnalysis.fromJson(
        json['construction'] as Map<String, dynamic>? ?? {},
      ),
      isUnorthodox: json['is_unorthodox'] as bool? ?? false,
      unorthodoxDescription: json['unorthodox_description'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      styleBucket: json['style_bucket'] as String? ?? 'casual',
      formality: json['formality'] as String? ?? 'casual',
      seasonality: json['seasonality'] as String? ?? 'all_season',
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'dense_caption': denseCaption,
    'ocr_text': ocrText,
    'era': era.toJson(),
    'vibes': vibeScores,
    'construction': construction.toJson(),
    'is_unorthodox': isUnorthodox,
    'unorthodox_description': unorthodoxDescription,
    'tags': tags,
    'style_bucket': styleBucket,
    'formality': formality,
    'seasonality': seasonality,
    'analyzed_at': analyzedAt.toIso8601String(),
  };
}

/// User's learned style profile
class UserStyleProfile {
  final String userId;
  final List<double>? styleVector;
  final int totalInteractions;
  final int wearsCount;
  final int likesCount;
  final int rejectsCount;
  final int editsCount;
  final Map<String, double> dominantVibes;
  final Map<String, double> avoidedVibes;
  final DateTime? lastInteractionAt;

  const UserStyleProfile({
    required this.userId,
    this.styleVector,
    required this.totalInteractions,
    required this.wearsCount,
    required this.likesCount,
    required this.rejectsCount,
    required this.editsCount,
    required this.dominantVibes,
    required this.avoidedVibes,
    this.lastInteractionAt,
  });

  /// Check if user has enough interactions for meaningful recommendations
  bool get hasLearnedPreferences => totalInteractions >= 10;

  /// Get top 3 dominant vibes
  List<String> get topVibes {
    final sorted = dominantVibes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  /// Calculate engagement score
  double get engagementScore {
    if (totalInteractions == 0) return 0.0;
    final positiveActions = wearsCount + likesCount + editsCount;
    return positiveActions / totalInteractions;
  }

  factory UserStyleProfile.fromJson(Map<String, dynamic> json) {
    return UserStyleProfile(
      userId: json['user_id'] as String,
      styleVector: (json['style_vector'] as List<dynamic>?)?.cast<double>(),
      totalInteractions: json['total_interactions'] as int? ?? 0,
      wearsCount: json['wears_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      rejectsCount: json['rejects_count'] as int? ?? 0,
      editsCount: json['edits_count'] as int? ?? 0,
      dominantVibes: (json['dominant_vibes'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ?? {},
      avoidedVibes: (json['avoided_vibes'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ?? {},
      lastInteractionAt: json['last_interaction_at'] != null
          ? DateTime.parse(json['last_interaction_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'style_vector': styleVector,
    'total_interactions': totalInteractions,
    'wears_count': wearsCount,
    'likes_count': likesCount,
    'rejects_count': rejectsCount,
    'edits_count': editsCount,
    'dominant_vibes': dominantVibes,
    'avoided_vibes': avoidedVibes,
    'last_interaction_at': lastInteractionAt?.toIso8601String(),
  };

  /// Empty profile for new users
  factory UserStyleProfile.empty(String userId) {
    return UserStyleProfile(
      userId: userId,
      totalInteractions: 0,
      wearsCount: 0,
      likesCount: 0,
      rejectsCount: 0,
      editsCount: 0,
      dominantVibes: {},
      avoidedVibes: {},
    );
  }
}

/// Vibe anchor definition
class VibeAnchor {
  final String id;
  final String vibeName;
  final String displayName;
  final String? description;
  final double trendScore;

  const VibeAnchor({
    required this.id,
    required this.vibeName,
    required this.displayName,
    this.description,
    this.trendScore = 0.5,
  });

  factory VibeAnchor.fromJson(Map<String, dynamic> json) {
    return VibeAnchor(
      id: json['id'] as String,
      vibeName: json['vibe_name'] as String,
      displayName: json['vibe_display_name'] as String? ?? json['vibe_name'] as String,
      description: json['vibe_description'] as String?,
      trendScore: (json['trend_score'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

/// Interaction types for active learning
enum StyleInteractionType {
  wear,
  like,
  save,
  reject,
  skip,
  tagEdit,
  vibeConfirm,
  vibeReject,
}

extension StyleInteractionTypeExtension on StyleInteractionType {
  String get value {
    switch (this) {
      case StyleInteractionType.wear: return 'wear';
      case StyleInteractionType.like: return 'like';
      case StyleInteractionType.save: return 'save';
      case StyleInteractionType.reject: return 'reject';
      case StyleInteractionType.skip: return 'skip';
      case StyleInteractionType.tagEdit: return 'tag_edit';
      case StyleInteractionType.vibeConfirm: return 'vibe_confirm';
      case StyleInteractionType.vibeReject: return 'vibe_reject';
    }
  }

  double get weight {
    switch (this) {
      case StyleInteractionType.wear: return 1.0;
      case StyleInteractionType.like: return 0.5;
      case StyleInteractionType.save: return 0.5;
      case StyleInteractionType.reject: return -0.5;
      case StyleInteractionType.skip: return -0.1;
      case StyleInteractionType.tagEdit: return 2.0;
      case StyleInteractionType.vibeConfirm: return 1.5;
      case StyleInteractionType.vibeReject: return -1.0;
    }
  }

  bool get isPositive => weight > 0;
}
