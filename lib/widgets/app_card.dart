import 'package:flutter/material.dart';
import 'package:styleum/theme/theme.dart';

/// Styleum design system card with consistent styling.
/// White background, subtle border, minimal shadow.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool elevated;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.elevated = false,
    this.onTap,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null;
    final showElevated = widget.elevated || _isPressed;

    return GestureDetector(
      onTapDown: isInteractive ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isInteractive
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: isInteractive ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: AppAnimations.normal,
        curve: AppAnimations.easeOut,
        transform: isInteractive && _isPressed
            ? Matrix4.translationValues(0.0, -2.0, 0.0)
            : Matrix4.identity(),
        padding: widget.padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(
            widget.borderRadius ?? AppSpacing.radiusLg,
          ),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: showElevated ? const [AppShadows.cardElevated] : null,
        ),
        child: widget.child,
      ),
    );
  }
}
