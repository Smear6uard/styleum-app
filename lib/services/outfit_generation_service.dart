/// Outfit Generation Service
/// 
/// The main orchestrator for the Hybrid Pipeline:
/// Step 1: Candidate Generation (Anchor-based, instant)
/// Step 2: Rules Pre-Filter (Safety net, instant)  
/// Step 3: Claude Haiku Scoring (Fashion judgment, ~500ms)
/// Step 4: Diversity Enforcement (Ensure variety, instant)
///
/// Total cost: ~$0.002 per generation
/// Total time: ~600-900ms (or instant with pre-generation)

import 'dart:math';
import 'package:styleum/models/wardrobe_item.dart';
import 'package:styleum/models/outfit.dart';
import 'rules_engine.dart';
import 'candidate_generator.dart';
import 'haiku_scoring_service.dart';

/// Result of outfit generation
class GenerationResult {
  final List<ScoredOutfit> outfits;
  final int candidatesGenerated;
  final int candidatesAfterRules;
  final Duration totalLatency;
  final int tokensUsed;
  final double estimatedCost;
  final String? error;

  const GenerationResult({
    required this.outfits,
    required this.candidatesGenerated,
    required this.candidatesAfterRules,
    required this.totalLatency,
    required this.tokensUsed,
    required this.estimatedCost,
    this.error,
  });

  bool get isSuccess => error == null && outfits.isNotEmpty;

  factory GenerationResult.error(String message) {
    return GenerationResult(
      outfits: [],
      candidatesGenerated: 0,
      candidatesAfterRules: 0,
      totalLatency: Duration.zero,
      tokensUsed: 0,
      estimatedCost: 0,
      error: message,
    );
  }
}

/// Main outfit generation service
class OutfitGenerationService {
  final CandidateGenerator _candidateGenerator;
  final HaikuScoringService _haikuService;

  OutfitGenerationService({
    required HaikuScoringService haikuService,
    CandidateGenerator? candidateGenerator,
  })  : _haikuService = haikuService,
        _candidateGenerator = candidateGenerator ?? CandidateGenerator();

  /// Generate outfits for a user
  /// 
  /// [wardrobe] - User's complete wardrobe
  /// [weather] - Current weather context
  /// [preferences] - User's style preferences
  /// [recentlyWornIds] - IDs of items worn in last N days
  /// [targetCount] - Number of outfits to return (default 6)
  Future<GenerationResult> generateOutfits({
    required List<WardrobeItem> wardrobe,
    WeatherContext? weather,
    StylePreferences? preferences,
    Set<String> recentlyWornIds = const {},
    int targetCount = 6,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Check minimum wardrobe size
    final tops = wardrobe.where((i) => i.category == ClothingCategory.top).length;
    final bottoms = wardrobe.where((i) => i.category == ClothingCategory.bottom).length;
    final shoes = wardrobe.where((i) => i.category == ClothingCategory.shoes).length;

    if (tops < 1 || bottoms < 1 || shoes < 1) {
      return GenerationResult.error(
        'Need at least 1 top, 1 bottom, and 1 pair of shoes to generate outfits.',
      );
    }

    final totalItems = wardrobe.length;
    if (totalItems < 5) {
      return GenerationResult.error(
        'Add ${5 - totalItems} more items to unlock outfit generation.',
      );
    }

    // Determine rule mode
    final ruleMode = RulesEngine.getModeForWardrobeSize(totalItems);

    // Create rules engine
    final rulesEngine = RulesEngine(
      mode: ruleMode,
      weather: weather,
      recentlyWornIds: recentlyWornIds,
    );

    // Generation config based on wardrobe size
    final config = GenerationConfig(
      maxCandidates: _getMaxCandidates(totalItems),
      maxAnchors: _getMaxAnchors(totalItems),
      prioritizeUnworn: true,
      enableOuterwear: weather?.needsJacket ?? false,
      enableAccessories: totalItems > 15,
    );

    // Step 1 & 2: Generate and filter candidates
    final candidates = _candidateGenerator.generateCandidates(
      wardrobe: wardrobe,
      weather: weather,
      rulesEngine: rulesEngine,
      config: config,
      preferences: preferences,
    );

    if (candidates.isEmpty) {
      return GenerationResult.error(
        'Could not generate any valid outfit combinations. Try adding more items.',
      );
    }

    // Step 3: AI Scoring
    final scoringResponse = await _haikuService.scoreOutfits(
      candidates: candidates,
      weather: weather,
      preferences: preferences,
      topN: targetCount,
    );

    // Step 4: Build final outfits with diversity
    final scoredOutfits = _buildScoredOutfits(
      candidates: candidates,
      scoringData: scoringResponse.outfits,
      targetCount: targetCount,
    );

    // Apply diversity enforcement
    final diverseOutfits = _enforceDiversity(scoredOutfits, targetCount);

    stopwatch.stop();

    // Calculate cost (Haiku: $0.25/1M input, $1.25/1M output, ~60% input)
    final estimatedCost = scoringResponse.tokensUsed * 0.0000006; // ~$0.0006/1k tokens blended

    return GenerationResult(
      outfits: diverseOutfits,
      candidatesGenerated: candidates.length,
      candidatesAfterRules: candidates.length, // Already filtered
      totalLatency: stopwatch.elapsed,
      tokensUsed: scoringResponse.tokensUsed,
      estimatedCost: estimatedCost,
    );
  }

  /// Build scored outfits from candidates and AI data
  List<ScoredOutfit> _buildScoredOutfits({
    required List<OutfitCandidate> candidates,
    required List<ScoredOutfitData> scoringData,
    required int targetCount,
  }) {
    final outfits = <ScoredOutfit>[];
    final usedIndices = <int>{};

    // First, add AI-selected outfits in order
    for (final data in scoringData) {
      if (data.index >= 0 && data.index < candidates.length && !usedIndices.contains(data.index)) {
        final candidate = candidates[data.index];
        
        // Combine rule score with AI vibe score
        // Rule score: 0-100, Vibe score: -5 to +5 (scaled to -10 to +10)
        final finalScore = (candidate.ruleScore + (data.vibeScore * 2)).clamp(0, 100);

        outfits.add(ScoredOutfit(
          id: '${candidate.candidateId}_${DateTime.now().millisecondsSinceEpoch}',
          candidate: candidate,
          score: finalScore,
          whyItWorks: data.whyItWorks,
          stylingTip: data.stylingTip,
          vibes: data.vibes,
        ));
        usedIndices.add(data.index);
      }
    }

    // Fill remaining slots with rule-scored candidates
    if (outfits.length < targetCount) {
      for (var i = 0; i < candidates.length && outfits.length < targetCount; i++) {
        if (!usedIndices.contains(i)) {
          final candidate = candidates[i];
          outfits.add(ScoredOutfit(
            id: '${candidate.candidateId}_${DateTime.now().millisecondsSinceEpoch}',
            candidate: candidate,
            score: candidate.ruleScore,
            whyItWorks: 'A well-coordinated combination.',
            vibes: [],
          ));
          usedIndices.add(i);
        }
      }
    }

    // Sort by score
    outfits.sort((a, b) => b.score.compareTo(a.score));

    return outfits;
  }

  /// Enforce diversity in final selection
  /// Ensures variety in colors, styles, and items
  List<ScoredOutfit> _enforceDiversity(List<ScoredOutfit> outfits, int targetCount) {
    if (outfits.length <= 3) return outfits; // Not enough to diversify

    final selected = <ScoredOutfit>[];
    final usedTopIds = <String>{};
    final usedBottomIds = <String>{};
    final usedColorCombos = <String>{};
    final usedStyles = <StyleBucket>{};

    // First pass: prioritize variety
    for (final outfit in outfits) {
      if (selected.length >= targetCount) break;

      final topId = outfit.top.id;
      final bottomId = outfit.bottom.id;
      final colorCombo = '${outfit.top.colorPrimary}_${outfit.bottom.colorPrimary}';
      final style = outfit.top.styleBucket;

      // Check if this adds variety
      final addsVariety = !usedTopIds.contains(topId) ||
          !usedBottomIds.contains(bottomId) ||
          !usedColorCombos.contains(colorCombo) ||
          !usedStyles.contains(style);

      if (addsVariety || selected.length < 3) {
        // Always take top 3, then prioritize variety
        selected.add(outfit);
        usedTopIds.add(topId);
        usedBottomIds.add(bottomId);
        usedColorCombos.add(colorCombo);
        usedStyles.add(style);
      }
    }

    // Second pass: fill remaining slots by score
    if (selected.length < targetCount) {
      for (final outfit in outfits) {
        if (selected.length >= targetCount) break;
        if (!selected.contains(outfit)) {
          selected.add(outfit);
        }
      }
    }

    return selected;
  }

  /// Determine max candidates based on wardrobe size
  int _getMaxCandidates(int wardrobeSize) {
    if (wardrobeSize < 10) return 20;
    if (wardrobeSize < 25) return 35;
    if (wardrobeSize < 50) return 50;
    return 75;
  }

  /// Determine max anchors based on wardrobe size
  int _getMaxAnchors(int wardrobeSize) {
    if (wardrobeSize < 10) return 3;
    if (wardrobeSize < 25) return 5;
    return 7;
  }
}

/// Pre-generation service for nightly queue
class PreGenerationService {
  final OutfitGenerationService _generationService;

  PreGenerationService({required OutfitGenerationService generationService})
      : _generationService = generationService;

  /// Generate and cache outfits for the next day
  /// Called by nightly cron job (4 AM)
  Future<Map<String, dynamic>> preGenerateForUser({
    required String userId,
    required List<WardrobeItem> wardrobe,
    required WeatherContext forecastWeather,
    StylePreferences? preferences,
    Set<String> recentlyWornIds = const {},
  }) async {
    final result = await _generationService.generateOutfits(
      wardrobe: wardrobe,
      weather: forecastWeather,
      preferences: preferences,
      recentlyWornIds: recentlyWornIds,
      targetCount: 6,
    );

    if (!result.isSuccess) {
      return {
        'success': false,
        'error': result.error,
        'user_id': userId,
      };
    }

    // Format for daily_queue storage
    return {
      'success': true,
      'user_id': userId,
      'date': DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0],
      'outfits': result.outfits.map((o) => o.toJson()).toList(),
      'weather_context': {
        'temp_f': forecastWeather.tempFahrenheit,
        'condition': forecastWeather.condition,
        'description': forecastWeather.description,
      },
      'generated_at': DateTime.now().toIso8601String(),
      'metadata': {
        'candidates_generated': result.candidatesGenerated,
        'latency_ms': result.totalLatency.inMilliseconds,
        'tokens_used': result.tokensUsed,
        'estimated_cost': result.estimatedCost,
      },
    };
  }
}
