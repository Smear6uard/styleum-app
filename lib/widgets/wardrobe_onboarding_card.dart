import 'package:flutter/material.dart';
import 'package:styleum/theme/theme.dart';

/// Wardrobe onboarding card with three display states based on item count.
///
/// - 0-4 items: Full card with title, subtitle, progress, and CTA
/// - 5-10 items: Collapsed card with encouragement message
/// - 11+ items: Hidden (returns empty widget)
///
/// Transitions between states are animated with fade and size changes.
class WardrobeOnboardingCard extends StatelessWidget {
  final int wardrobeCount;
  final VoidCallback onAddPressed;

  const WardrobeOnboardingCard({
    super.key,
    required this.wardrobeCount,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    // Hidden state: 11+ items
    if (wardrobeCount > 10) {
      return const SizedBox.shrink(key: ValueKey('hidden'));
    }

    // Collapsed state: 5-10 items
    if (wardrobeCount >= 5) {
      return _buildCollapsed();
    }

    // Full state: 0-4 items
    return _buildFull();
  }

  Widget _buildFull() {
    return Container(
      key: const ValueKey('full'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your wardrobe',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a few pieces to personalize your daily outfits',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$wardrobeCount of 5 items added',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          _buildPrimaryButton('Add to wardrobe'),
        ],
      ),
    );
  }

  Widget _buildCollapsed() {
    return Container(
      key: const ValueKey('collapsed'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.card],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your wardrobe',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nice — keep going! $wardrobeCount items',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _buildSecondaryButton('Add more'),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String label) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onAddPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label) {
    return TextButton(
      onPressed: onAddPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
