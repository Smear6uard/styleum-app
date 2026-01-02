import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/models/achievement.dart';

enum AchievementAction {
  wardrobeItemAdded,
  outfitGenerated,
  outfitWorn,
  outfitShared,
  streakUpdated,
  stylePointsEarned,
}

class AchievementsService {
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Fetch all achievements with user's progress
  Future<List<Achievement>> getAchievements(String userId) async {
    try {
      // Join definitions with user progress
      final response = await _supabase
          .from('achievement_definitions')
          .select('''
            id, title, description, category, rarity, target_progress, icon_name, sort_order,
            user_achievements!left(current_progress, unlocked_at, seen_at)
          ''')
          .eq('user_achievements.user_id', userId)
          .order('category')
          .order('sort_order');

      return (response as List).map((item) {
        final userProgress = item['user_achievements'] as List?;
        final progress =
            userProgress?.isNotEmpty == true ? userProgress!.first : null;

        return Achievement.fromJson({
          ...item,
          'current_progress': progress?['current_progress'] ?? 0,
          'unlocked_at': progress?['unlocked_at'],
          'seen_at': progress?['seen_at'],
        });
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Initialize user achievements (create rows for missing achievements)
  Future<void> initializeUserAchievements(String userId) async {
    try {
      // Get all achievement IDs
      final definitions =
          await _supabase.from('achievement_definitions').select('id');

      // Get user's existing achievement IDs
      final existing = await _supabase
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);

      final existingIds =
          (existing as List).map((e) => e['achievement_id']).toSet();

      // Insert missing achievements
      final missing = (definitions as List)
          .where((d) => !existingIds.contains(d['id']))
          .map((d) => {
                'user_id': userId,
                'achievement_id': d['id'],
                'current_progress': 0,
              })
          .toList();

      if (missing.isNotEmpty) {
        await _supabase.from('user_achievements').insert(missing);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Record an action and update relevant achievements
  Future<void> recordAction(
    String userId,
    AchievementAction action, {
    int value = 1,
  }) async {
    try {
      final achievementIds = _getAchievementIdsForAction(action);

      for (final achievementId in achievementIds) {
        await _incrementProgress(userId, achievementId, value);
      }
    } catch (e) {
      // Ignore errors - don't break main flow
    }
  }

  List<String> _getAchievementIdsForAction(AchievementAction action) {
    switch (action) {
      case AchievementAction.wardrobeItemAdded:
        return [
          'wardrobe_starter',
          'wardrobe_10',
          'wardrobe_25',
          'wardrobe_50',
          'wardrobe_100'
        ];
      case AchievementAction.outfitGenerated:
        return ['outfit_first', 'outfit_10', 'outfit_50', 'outfit_100'];
      case AchievementAction.outfitWorn:
        return ['outfit_wore', 'outfit_wore_10'];
      case AchievementAction.outfitShared:
        return ['social_first', 'social_10'];
      case AchievementAction.streakUpdated:
        return ['streak_3', 'streak_7', 'streak_14', 'streak_30', 'streak_100'];
      case AchievementAction.stylePointsEarned:
        return ['style_40', 'style_60', 'style_80', 'style_95'];
    }
  }

  Future<void> _incrementProgress(
    String userId,
    String achievementId,
    int amount,
  ) async {
    // Get current progress and check if already unlocked
    var result = await _supabase
        .from('user_achievements')
        .select('current_progress, unlocked_at')
        .eq('user_id', userId)
        .eq('achievement_id', achievementId)
        .maybeSingle();

    // Auto-create row if missing
    if (result == null) {
      await _supabase.from('user_achievements').insert({
        'user_id': userId,
        'achievement_id': achievementId,
        'current_progress': 0,
      });
      result = {'current_progress': 0, 'unlocked_at': null};
    }

    if (result['unlocked_at'] != null) return; // Already unlocked

    final currentProgress = result['current_progress'] as int;
    final newProgress = currentProgress + amount;

    // Get target
    final def = await _supabase
        .from('achievement_definitions')
        .select('target_progress')
        .eq('id', achievementId)
        .single();

    final target = def['target_progress'] as int;
    final isNowUnlocked = newProgress >= target;

    await _supabase
        .from('user_achievements')
        .update({
          'current_progress': newProgress,
          'unlocked_at':
              isNowUnlocked ? DateTime.now().toIso8601String() : null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('achievement_id', achievementId);
  }

  /// Mark achievement as seen
  Future<void> markAsSeen(String userId, String achievementId) async {
    try {
      await _supabase
          .from('user_achievements')
          .update({
            'seen_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('achievement_id', achievementId);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get count of unseen unlocked achievements
  Future<int> getUnseenCount(String userId) async {
    try {
      final response = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId)
          .not('unlocked_at', 'is', null)
          .filter('seen_at', 'is', null)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      return 0;
    }
  }

  /// Get summary stats for profile
  Future<Map<String, int>> getAchievementStats(String userId) async {
    try {
      final total = await _supabase
          .from('achievement_definitions')
          .select()
          .count(CountOption.exact);

      final unlocked = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId)
          .not('unlocked_at', 'is', null)
          .count(CountOption.exact);

      final unseen = await getUnseenCount(userId);

      return {
        'total': total.count,
        'unlocked': unlocked.count,
        'unseen': unseen,
      };
    } catch (e) {
      return {'total': 22, 'unlocked': 0, 'unseen': 0};
    }
  }
}
