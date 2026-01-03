// AI Analysis Service
//
// Handles communication with the AI tagging pipeline:
// - Trigger analysis for new items
// - Track analysis status
// - Fetch analysis results
// - Update user style vector on interactions

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/models/ai_analysis.dart';

/// Status of an item's AI analysis
enum AnalysisStatus {
  pending,
  analyzing,
  completed,
  failed,
}

/// Result of triggering an analysis
class AnalysisTriggerResult {
  final bool success;
  final String? error;
  final AIAnalysisResult? analysis;
  final int latencyMs;

  const AnalysisTriggerResult({
    required this.success,
    this.error,
    this.analysis,
    this.latencyMs = 0,
  });

  factory AnalysisTriggerResult.success(AIAnalysisResult analysis, int latencyMs) {
    return AnalysisTriggerResult(
      success: true,
      analysis: analysis,
      latencyMs: latencyMs,
    );
  }

  factory AnalysisTriggerResult.failure(String error) {
    return AnalysisTriggerResult(success: false, error: error);
  }
}

/// Service for AI analysis operations
class AIAnalysisService {
  final SupabaseClient _supabase;

  AIAnalysisService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Analyze a wardrobe item
  /// 
  /// Called after image upload. Triggers the full pipeline:
  /// Florence-2 → Embedding → Gemini → Vibe matching
  Future<AnalysisTriggerResult> analyzeItem({
    required String itemId,
    required String imageUrl,
    String? userContext,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'analyze-item',
        body: {
          'item_id': itemId,
          'image_url': imageUrl,
          'user_context': userContext,
        },
      );

      if (response.status != 200) {
        final error = response.data['message'] ?? 'Analysis failed';
        return AnalysisTriggerResult.failure(error);
      }

      final data = response.data as Map<String, dynamic>;
      final analysis = AIAnalysisResult.fromJson(data['analysis']);
      final latencyMs = data['metadata']?['latency_ms'] as int? ?? 0;

      return AnalysisTriggerResult.success(analysis, latencyMs);
    } catch (e) {
      return AnalysisTriggerResult.failure(e.toString());
    }
  }

  /// Get analysis for an item (if already analyzed)
  Future<AIAnalysisResult?> getAnalysis(String itemId) async {
    try {
      final response = await _supabase
          .from('wardrobe_items')
          .select('''
            dense_caption,
            ocr_text,
            era_detected,
            era_confidence,
            vibe_scores,
            is_unorthodox,
            unorthodox_description,
            tags,
            style_bucket,
            formality,
            seasonality,
            ai_metadata
          ''')
          .eq('id', itemId)
          .single();

      if (response['dense_caption'] == null) {
        return null; // Not yet analyzed
      }

      // Reconstruct the analysis result
      final aiMetadata = response['ai_metadata'] as Map<String, dynamic>?;
      final geminiData = aiMetadata?['gemini'] as Map<String, dynamic>?;

      return AIAnalysisResult(
        denseCaption: response['dense_caption'] as String? ?? '',
        ocrText: response['ocr_text'] as String?,
        era: EraAnalysis(
          detected: response['era_detected'] as String? ?? 'unknown',
          confidence: (response['era_confidence'] as num?)?.toDouble() ?? 0.0,
          reasoning: geminiData?['era']?['reasoning'] as String? ?? '',
        ),
        vibeScores: (response['vibe_scores'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ?? {},
        construction: ConstructionAnalysis.fromJson(
          geminiData?['construction'] as Map<String, dynamic>? ?? {},
        ),
        isUnorthodox: response['is_unorthodox'] as bool? ?? false,
        unorthodoxDescription: response['unorthodox_description'] as String?,
        tags: (response['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        styleBucket: response['style_bucket'] as String? ?? 'casual',
        formality: response['formality'] as String? ?? 'casual',
        seasonality: response['seasonality'] as String? ?? 'all_season',
        analyzedAt: aiMetadata?['analyzed_at'] != null
            ? DateTime.parse(aiMetadata!['analyzed_at'] as String)
            : DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if an item has been analyzed
  Future<AnalysisStatus> getAnalysisStatus(String itemId) async {
    try {
      final response = await _supabase
          .from('wardrobe_items')
          .select('dense_caption, ai_metadata')
          .eq('id', itemId)
          .single();

      if (response['dense_caption'] != null) {
        return AnalysisStatus.completed;
      }

      return AnalysisStatus.pending;
    } catch (e) {
      return AnalysisStatus.failed;
    }
  }

  /// Get all available vibes
  Future<List<VibeAnchor>> getAvailableVibes() async {
    try {
      final response = await _supabase
          .from('vibe_centroids')
          .select('*')
          .order('vibe_name');

      return (response as List)
          .map((json) => VibeAnchor(
                id: json['id'] as String,
                vibeName: json['vibe_name'] as String,
                displayName: _formatVibeName(json['vibe_name'] as String),
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  String _formatVibeName(String name) {
    return name
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}

/// Service for user style learning
class StyleLearningService {
  final SupabaseClient _supabase;

  StyleLearningService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Record a style interaction (updates user style vector)
  Future<bool> recordInteraction({
    required StyleInteractionType type,
    String? itemId,
    String? outfitId,
    String? oldValue,
    String? newValue,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _supabase.functions.invoke(
        'update-style-vector',
        body: {
          'user_id': userId,
          'item_id': itemId,
          'outfit_id': outfitId,
          'interaction_type': type.value,
          'context': {
            if (oldValue != null) 'old_value': oldValue,
            if (newValue != null) 'new_value': newValue,
          },
        },
      );

      return response.status == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get user's style profile
  Future<UserStyleProfile> getStyleProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return UserStyleProfile.empty('');
    }

    try {
      final response = await _supabase
          .from('user_style_vectors')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return UserStyleProfile.empty(userId);
      }

      return UserStyleProfile.fromJson(response);
    } catch (e) {
      return UserStyleProfile.empty(userId);
    }
  }

  /// Confirm a vibe tag (positive signal)
  Future<bool> confirmVibe(String itemId, String vibeName) async {
    return recordInteraction(
      type: StyleInteractionType.vibeConfirm,
      itemId: itemId,
      newValue: vibeName,
    );
  }

  /// Reject a vibe tag (negative signal)
  Future<bool> rejectVibe(String itemId, String vibeName) async {
    return recordInteraction(
      type: StyleInteractionType.vibeReject,
      itemId: itemId,
      oldValue: vibeName,
    );
  }

  /// Edit a tag (strongest learning signal)
  Future<bool> editTag({
    required String itemId,
    required String field,
    required String oldValue,
    required String newValue,
  }) async {
    // First, update the database
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      // Update the item
      await _supabase
          .from('wardrobe_items')
          .update({
            field: newValue,
            'user_verified': true,
            'feedback_log': _supabase.rpc('array_append', params: {
              'arr': 'feedback_log',
              'elem': {
                'field': field,
                'old_value': oldValue,
                'new_value': newValue,
                'timestamp': DateTime.now().toIso8601String(),
              },
            }),
          })
          .eq('id', itemId);

      // Record the interaction
      return recordInteraction(
        type: StyleInteractionType.tagEdit,
        itemId: itemId,
        oldValue: oldValue,
        newValue: newValue,
      );
    } catch (e) {
      return false;
    }
  }

  /// Mark outfit as worn (strong positive signal)
  Future<bool> markOutfitWorn(String outfitId) async {
    return recordInteraction(
      type: StyleInteractionType.wear,
      outfitId: outfitId,
    );
  }

  /// Save/like an outfit (moderate positive signal)
  Future<bool> saveOutfit(String outfitId) async {
    return recordInteraction(
      type: StyleInteractionType.save,
      outfitId: outfitId,
    );
  }

  /// Reject an outfit (negative signal) with optional reason
  Future<bool> rejectOutfit(String outfitId, {String? reason}) async {
    return recordInteraction(
      type: StyleInteractionType.reject,
      outfitId: outfitId,
      newValue: reason, // Store reason in newValue field
    );
  }

  /// Skip an outfit (weak negative signal)
  Future<bool> skipOutfit(String outfitId) async {
    return recordInteraction(
      type: StyleInteractionType.skip,
      outfitId: outfitId,
    );
  }
}
