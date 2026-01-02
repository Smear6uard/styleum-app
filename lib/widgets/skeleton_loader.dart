import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:styleum/theme/theme.dart';

class SkeletonLoader extends StatelessWidget {
  static const Color baseColor = Color(0xFFE5E5E5);
  static const Color highlightColor = Color(0xFFFFFFFF);
  static const Duration duration = Duration(milliseconds: 1500);

  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: duration,
      child: child,
    );
  }
}

/// Skeleton for the home screen initial load.
class SkeletonHomeScreen extends StatelessWidget {
  const SkeletonHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            const SkeletonText(width: 120, height: 24),
            const SizedBox(height: 8),
            const SkeletonText(width: 200, height: 16),
            const SizedBox(height: AppSpacing.sectionGap),

            // Wardrobe card skeleton
            const SkeletonBox(height: 200, borderRadius: 16),
            const SizedBox(height: AppSpacing.sectionGap),

            // Top pick section
            const SkeletonText(width: 100, height: 20),
            const SizedBox(height: 16),
            const SkeletonBox(height: 300, borderRadius: 16),
            const SizedBox(height: AppSpacing.sectionGap),

            // Challenge section
            const SkeletonText(width: 140, height: 20),
            const SizedBox(height: 16),
            const SkeletonBox(height: 120, borderRadius: 16),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for outfit grid in style me screen.
class SkeletonOutfitGrid extends StatelessWidget {
  const SkeletonOutfitGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const SkeletonText(width: 180, height: 24),
            const SizedBox(height: 8),
            const SkeletonText(width: 240, height: 16),
            const SizedBox(height: AppSpacing.lg),

            // Grid of outfit cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return const SkeletonBox(borderRadius: 16);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for wardrobe item grid.
class SkeletonWardrobeGrid extends StatelessWidget {
  const SkeletonWardrobeGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: SkeletonBox(borderRadius: 12),
              ),
              const SizedBox(height: 8),
              const SkeletonText(width: 80, height: 14),
            ],
          );
        },
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonText({
    super.key,
    required this.width,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
