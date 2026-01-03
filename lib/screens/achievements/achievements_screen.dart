import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/models/achievement.dart';
import 'package:styleum/services/achievements_service.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/animated_list_item.dart';
import 'dart:math' as math;

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementsService _service = AchievementsService();
  AchievementCategory? _selectedCategory;
  List<Achievement> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    await _service.initializeUserAchievements(user.id);
    final achievements = await _service.getAchievements(user.id);

    if (mounted) {
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    }
  }

  List<Achievement> get _filteredAchievements {
    if (_selectedCategory == null) return _achievements;
    final filtered = _achievements
        .where((a) => a.category == _selectedCategory)
        .toList();
    // Sort by target_progress ASCENDING (easiest first)
    filtered.sort((a, b) => a.targetProgress.compareTo(b.targetProgress));
    return filtered;
  }

  int get _unlockedCount => _achievements.where((a) => a.isUnlocked).length;

  String _categoryName(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.wardrobe:
        return 'Wardrobe';
      case AchievementCategory.outfits:
        return 'Outfits';
      case AchievementCategory.streaks:
        return 'Streaks';
      case AchievementCategory.social:
        return 'Social';
      case AchievementCategory.style:
        return 'Style';
    }
  }

  void _onCardTapped(Achievement achievement) {
    if (achievement.isNew) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _service.markAsSeen(user.id, achievement.id);
        _loadAchievements();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Achievements',
          style: AppTypography.headingLarge.copyWith(
            letterSpacing: -0.03,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.slate),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressSummary(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildCategoryFilters(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildAchievementSections(),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressSummary() {
    final total = _achievements.length;
    final progressPercent = total > 0 ? _unlockedCount / total : 0.0;

    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_unlockedCount of $total',
            style: AppTypography.numberLarge.copyWith(
              letterSpacing: -0.03,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Achievements Unlocked',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progressPercent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progressPercent * 100).round()}%',
                style: AppTypography.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterTab('All', null),
          const SizedBox(width: 24),
          ...AchievementCategory.values.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(right: 24),
              child: _buildFilterTab(_categoryName(cat), cat),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, AchievementCategory? category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: isSelected ? label.length * 7.0 : 0,
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementSections() {
    if (_selectedCategory != null) {
      return _buildAchievementGrid(_filteredAchievements);
    }

    return Column(
      children: AchievementCategory.values.map((category) {
        final categoryAchievements =
            _achievements.where((a) => a.category == category).toList();
        if (categoryAchievements.isEmpty) return const SizedBox.shrink();

        // Sort by target_progress ASCENDING (easiest first)
        categoryAchievements.sort((a, b) => a.targetProgress.compareTo(b.targetProgress));

        final unlocked =
            categoryAchievements.where((a) => a.isUnlocked).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              _categoryName(category),
              '$unlocked/${categoryAchievements.length}',
            ),
            const SizedBox(height: 12),
            _buildAchievementGrid(categoryAchievements),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, String count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(count, style: AppTypography.labelSmall),
      ],
    );
  }

  Widget _buildAchievementGrid(List<Achievement> achievements) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        return AnimatedListItem(
          index: index,
          child: _FlipAchievementCard(
            achievement: achievements[index],
            onTap: () => _onCardTapped(achievements[index]),
          ),
        );
      },
    );
  }
}

/// 3D flip card widget for achievements
class _FlipAchievementCard extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onTap;

  const _FlipAchievementCard({
    required this.achievement,
    required this.onTap,
  });

  @override
  State<_FlipAchievementCard> createState() => _FlipAchievementCardState();
}

class _FlipAchievementCardState extends State<_FlipAchievementCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    HapticFeedback.lightImpact();
    if (_isFlipped) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    _isFlipped = !_isFlipped;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * math.pi;
          final isFront = angle < (math.pi / 2);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront
                ? _AchievementCardFront(
                    achievement: widget.achievement,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _AchievementCardBack(
                      achievement: widget.achievement,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// Front of achievement card (Icon + Title)
class _AchievementCardFront extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCardFront({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final rarityColor = achievement.rarityColor;

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Stack(
        children: [
          // Rarity indicator as top border
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: rarityColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: isUnlocked ? 1.0 : 0.52,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200, // Fixed height to prevent layout shift
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: NEW badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (achievement.isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Icon container
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        achievement.icon,
                        size: 24,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      achievement.title,
                      style: AppTypography.titleSmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                  // Bottom status
                  if (isUnlocked)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Unlocked',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(1),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: achievement.progressPercent,
                            child: Container(
                              decoration: BoxDecoration(
                                color: achievement.currentProgress == 0
                                    ? AppColors.textMuted
                                    : AppColors.slate,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${achievement.currentProgress}/${achievement.targetProgress}',
                          style: AppTypography.labelSmall.copyWith(
                            color: achievement.currentProgress == 0
                                ? AppColors.textMuted
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back of achievement card (Description + Requirement + Unlock Date)
class _AchievementCardBack extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCardBack({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final rarityColor = achievement.rarityColor;

    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Stack(
        children: [
          // Rarity indicator as top border
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: rarityColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: isUnlocked ? 1.0 : 0.52,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200, // Fixed height to prevent layout shift
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      achievement.description,
                      style: AppTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: achievement.progressPercent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: achievement.currentProgress == 0
                                ? AppColors.textMuted
                                : (isUnlocked
                                    ? AppColors.textPrimary
                                    : AppColors.slate),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${achievement.currentProgress}/${achievement.targetProgress}',
                      style: AppTypography.labelSmall.copyWith(
                        color: achievement.currentProgress == 0
                            ? AppColors.textMuted
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
