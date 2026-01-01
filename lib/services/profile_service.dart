import 'package:supabase_flutter/supabase_flutter.dart';

class Profile {
  final String? username;
  final int currentStreak;
  final int longestStreak;
  final int totalDaysActive;

  Profile({
    this.username,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalDaysActive = 0,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      username: json['username'] as String?,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      totalDaysActive: json['total_days_active'] as int? ?? 0,
    );
  }
}

class ProfileService {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<Profile?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('username, current_streak, longest_streak, total_days_active')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
