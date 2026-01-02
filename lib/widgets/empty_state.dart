import 'package:flutter/material.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/app_button.dart';

/// 4-part empty state component for Styleum.
/// Contains: headline, description, illustration/icon, and CTA button.
class EmptyState extends StatelessWidget {
  final String headline;
  final String description;
  final IconData icon;
  final String ctaLabel;
  final VoidCallback onCtaPressed;

  const EmptyState({
    super.key,
    required this.headline,
    required this.description,
    required this.icon,
    required this.ctaLabel,
    required this.onCtaPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon in cherry-tinted circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cherry.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppColors.cherry,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Headline
            Text(
              headline,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // CTA Button
            SizedBox(
              width: 200,
              child: AppButton.primary(
                label: ctaLabel,
                onPressed: onCtaPressed,
                fullWidth: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
