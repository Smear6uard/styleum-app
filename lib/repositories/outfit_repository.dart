/// Outfit Repository
/// 
/// Handles all outfit data operations:
/// - Fetching from daily_queue (pre-generated)
/// - Real-time generation via Edge Function
/// - Local caching with Hive
/// - Marking outfits as worn

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:styleum/models/wardrobe_item.dart';
import 'package:styleum/models/outfit.dart';

/// Repository for outfit operations
class OutfitRepository {
  final SupabaseClient _supabase;
  final Box<String> _cache;
  
  static const _cacheBoxName = 'outfit_cache';
  static const _dailyQueueKey = 'daily_queue';
  static const _cacheExpiry = Duration(hours: 4);

  OutfitRepository._({
    required SupabaseClient supabase,
    required Box<String> cache,
  }) : _supabase = supabase, _cache = cache;

  static Future<OutfitRepository> create() async {
    await Hive.initFlutter();
    final cache = await Hive.openBox<String>(_cacheBoxName);
    return OutfitRepository._(
      supabase: Supabase.instance.client,
      cache: cache,
    );
  }

  /// Get today's outfits (from pre-generated queue or real-time)
  Future<OutfitResult> getTodaysOutfits({
    WeatherContext? weather,
    StylePreferences? preferences,
    bool forceRefresh = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return OutfitResult.error('Not authenticated');
    }

    // Check cache first (unless forcing refresh)
    if (!forceRefresh) {
      final cached = _getCachedOutfits();
      if (cached != null) {
        return OutfitResult.success(cached);
      }
    }

    // Try to get from daily_queue (pre-generated at 4 AM)
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    try {
      final queueResponse = await _supabase
          .from('daily_queue')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      if (queueResponse != null) {
        final outfits = _parseQueueOutfits(queueResponse);
        _cacheOutfits(outfits);
        return OutfitResult.success(outfits);
      }
    } catch (e) {
      // Queue miss - fall through to real-time generation
    }

    // Real-time generation via Edge Function
    return _generateRealTime(
      userId: userId,
      weather: weather,
      preferences: preferences,
    );
  }

  /// Generate outfits in real-time (for on-demand or first use)
  Future<OutfitResult> _generateRealTime({
    required String userId,
    WeatherContext? weather,
    StylePreferences? preferences,
  }) async {
    try {
      // Get recently worn items (last 3 days)
      final recentlyWorn = await _getRecentlyWornIds(userId);

      final response = await _supabase.functions.invoke(
        'generate-outfits',
        body: {
          'user_id': userId,
          'weather': weather != null ? {
            'temp_f': weather.tempFahrenheit,
            'condition': weather.condition,
            'humidity': weather.humidity,
            'wind_mph': weather.windMph,
            'description': weather.description,
          } : null,
          'preferences': preferences != null ? {
            'style_goal': preferences.styleGoal,
            'avoid_colors': preferences.avoidColors,
            'preferred_styles': preferences.preferredStyles.map((s) => s.name).toList(),
            'boldness_level': preferences.boldnessLevel,
            'occasion': preferences.occasion,
            'time_of_day': preferences.timeOfDay,
          } : null,
          'recently_worn_ids': recentlyWorn.toList(),
          'target_count': 6,
        },
      );

      if (response.status != 200) {
        final error = response.data['message'] ?? 'Generation failed';
        return OutfitResult.error(error);
      }

      final data = response.data as Map<String, dynamic>;
      final outfits = _parseGeneratedOutfits(data);
      
      _cacheOutfits(outfits);
      
      return OutfitResult.success(
        outfits,
        metadata: GenerationMetadata.fromJson(data['metadata'] ?? {}),
      );
    } catch (e) {
      return OutfitResult.error('Failed to generate outfits: $e');
    }
  }

  /// Mark an outfit as "Wear This Today"
  Future<bool> markAsWorn(ScoredOutfit outfit) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Log to daily_log
      await _supabase.from('daily_log').upsert({
        'user_id': userId,
        'date': today,
        'outfit_id': outfit.id,
        'top_id': outfit.top.id,
        'bottom_id': outfit.bottom.id,
        'shoes_id': outfit.shoes.id,
        'outerwear_id': outfit.outerwear?.id,
        'accessory_id': outfit.accessory?.id,
        'wore_suggested': true,
        'confirmed_at': DateTime.now().toIso8601String(),
      });

      // Increment times_worn for each item
      await _incrementTimesWorn(outfit.top.id);
      await _incrementTimesWorn(outfit.bottom.id);
      await _incrementTimesWorn(outfit.shoes.id);
      if (outfit.outerwear != null) {
        await _incrementTimesWorn(outfit.outerwear!.id);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save an outfit to favorites
  Future<bool> saveOutfit(ScoredOutfit outfit) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _supabase.from('saved_outfits').insert({
        'user_id': userId,
        'outfit_data': outfit.toJson(),
        'saved_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get count of saved outfits (for paywall trigger)
  Future<int> getSavedOutfitCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('saved_outfits')
          .select('id')
          .eq('user_id', userId);
      
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Invalidate cache (call when wardrobe changes)
  Future<void> invalidateCache() async {
    await _cache.delete(_dailyQueueKey);
  }

  // Private helpers

  List<ScoredOutfit>? _getCachedOutfits() {
    final cached = _cache.get(_dailyQueueKey);
    if (cached == null) return null;

    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp'] as String);
      
      // Check if cache is still valid
      if (DateTime.now().difference(timestamp) > _cacheExpiry) {
        return null;
      }

      final outfitsList = data['outfits'] as List<dynamic>;
      return outfitsList.map((o) => _parseScoredOutfit(o)).toList();
    } catch (e) {
      return null;
    }
  }

  void _cacheOutfits(List<ScoredOutfit> outfits) {
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'outfits': outfits.map((o) => o.toJson()).toList(),
    };
    _cache.put(_dailyQueueKey, jsonEncode(data));
  }

  List<ScoredOutfit> _parseQueueOutfits(Map<String, dynamic> queue) {
    final outfitsJson = queue['outfits'] as List<dynamic>;
    return outfitsJson.map((o) => _parseScoredOutfit(o)).toList();
  }

  List<ScoredOutfit> _parseGeneratedOutfits(Map<String, dynamic> response) {
    final outfitsJson = response['outfits'] as List<dynamic>;
    return outfitsJson.map((o) => _parseScoredOutfit(o)).toList();
  }

  ScoredOutfit _parseScoredOutfit(Map<String, dynamic> json) {
    final top = WardrobeItem.fromJson(json['top'] as Map<String, dynamic>);
    final bottom = WardrobeItem.fromJson(json['bottom'] as Map<String, dynamic>);
    final shoes = WardrobeItem.fromJson(json['shoes'] as Map<String, dynamic>);
    final outerwear = json['outerwear'] != null 
        ? WardrobeItem.fromJson(json['outerwear'] as Map<String, dynamic>)
        : null;
    final accessory = json['accessory'] != null
        ? WardrobeItem.fromJson(json['accessory'] as Map<String, dynamic>)
        : null;

    return ScoredOutfit(
      id: json['id'] as String,
      candidate: OutfitCandidate(
        top: top,
        bottom: bottom,
        shoes: shoes,
        outerwear: outerwear,
        accessory: accessory,
        ruleScore: json['score'] as int? ?? 80,
      ),
      score: json['score'] as int? ?? 80,
      whyItWorks: json['why_it_works'] as String? ?? 'A well-coordinated outfit.',
      stylingTip: json['styling_tip'] as String?,
      vibes: (json['vibes'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Future<Set<String>> _getRecentlyWornIds(String userId) async {
    try {
      final threeDaysAgo = DateTime.now()
          .subtract(const Duration(days: 3))
          .toIso8601String()
          .split('T')[0];

      final response = await _supabase
          .from('daily_log')
          .select('top_id, bottom_id')
          .eq('user_id', userId)
          .gte('date', threeDaysAgo);

      final ids = <String>{};
      for (final row in response as List) {
        if (row['top_id'] != null) ids.add(row['top_id'] as String);
        if (row['bottom_id'] != null) ids.add(row['bottom_id'] as String);
      }
      return ids;
    } catch (e) {
      return {};
    }
  }

  Future<void> _incrementTimesWorn(String itemId) async {
    await _supabase.rpc('increment_times_worn', params: {'item_id': itemId});
  }
}

/// Result wrapper for outfit operations
class OutfitResult {
  final List<ScoredOutfit>? outfits;
  final String? error;
  final GenerationMetadata? metadata;

  const OutfitResult._({this.outfits, this.error, this.metadata});

  factory OutfitResult.success(
    List<ScoredOutfit> outfits, {
    GenerationMetadata? metadata,
  }) {
    return OutfitResult._(outfits: outfits, metadata: metadata);
  }

  factory OutfitResult.error(String message) {
    return OutfitResult._(error: message);
  }

  bool get isSuccess => outfits != null && error == null;
}

/// Metadata from generation
class GenerationMetadata {
  final int candidatesGenerated;
  final int latencyMs;
  final int tokensUsed;
  final double estimatedCost;

  const GenerationMetadata({
    required this.candidatesGenerated,
    required this.latencyMs,
    required this.tokensUsed,
    required this.estimatedCost,
  });

  factory GenerationMetadata.fromJson(Map<String, dynamic> json) {
    return GenerationMetadata(
      candidatesGenerated: json['candidates_generated'] as int? ?? 0,
      latencyMs: json['latency_ms'] as int? ?? 0,
      tokensUsed: json['tokens_used'] as int? ?? 0,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
