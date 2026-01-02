import 'package:flutter/material.dart';
import 'package:styleum/theme/app_colors.dart';

enum AchievementRarity { common, uncommon, rare, epic, legendary }

enum AchievementCategory { wardrobe, outfits, streaks, social, style }

class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final AchievementRarity rarity;
  final int currentProgress;
  final int targetProgress;
  final String iconName;
  final DateTime? unlockedAt;
  final DateTime? seenAt;
  final int sortOrder;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.rarity,
    required this.currentProgress,
    required this.targetProgress,
    required this.iconName,
    this.unlockedAt,
    this.seenAt,
    this.sortOrder = 0,
  });

  bool get isUnlocked => currentProgress >= targetProgress;
  bool get isNew => isUnlocked && seenAt == null;
  double get progressPercent =>
      (currentProgress / targetProgress).clamp(0.0, 1.0);

  /// Rarity colors using existing theme constants
  Color get rarityColor {
    switch (rarity) {
      case AchievementRarity.common:
        return AppColors.border;
      case AchievementRarity.uncommon:
        return AppColors.textMuted;
      case AchievementRarity.rare:
        return AppColors.slate;
      case AchievementRarity.epic:
        return AppColors.textSecondary;
      case AchievementRarity.legendary:
        return AppColors.textPrimary;
    }
  }

  /// Map icon name string to IconData
  IconData get icon {
    const iconMap = <String, IconData>{
      'checkroom': Icons.checkroom_outlined,
      'layers': Icons.layers_outlined,
      'grid_view': Icons.grid_view_outlined,
      'inventory_2': Icons.inventory_2_outlined,
      'workspace_premium': Icons.workspace_premium_outlined,
      'auto_awesome': Icons.auto_awesome_outlined,
      'check_circle': Icons.check_circle_outlined,
      'explore': Icons.explore_outlined,
      'event_repeat': Icons.event_repeat_outlined,
      'science': Icons.science_outlined,
      'bolt': Icons.bolt_outlined,
      'local_fire_department': Icons.local_fire_department_outlined,
      'whatshot': Icons.whatshot_outlined,
      'track_changes': Icons.track_changes_outlined,
      'star': Icons.star_outline,
      'emoji_events': Icons.emoji_events_outlined,
      'share': Icons.share_outlined,
      'group': Icons.group_outlined,
      'eco': Icons.eco_outlined,
      'park': Icons.park_outlined,
      'diamond': Icons.diamond_outlined,
    };
    return iconMap[iconName] ?? Icons.emoji_events_outlined;
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: AchievementCategory.values.firstWhere(
        (c) => c.name == json['category'],
      ),
      rarity: AchievementRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
      ),
      currentProgress: json['current_progress'] as int? ?? 0,
      targetProgress: json['target_progress'] as int,
      iconName: json['icon_name'] as String,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
      seenAt: json['seen_at'] != null
          ? DateTime.parse(json['seen_at'] as String)
          : null,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'current_progress': currentProgress,
        'unlocked_at': unlockedAt?.toIso8601String(),
        'seen_at': seenAt?.toIso8601String(),
      };
}
