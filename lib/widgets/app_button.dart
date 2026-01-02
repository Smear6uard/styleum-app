import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:styleum/theme/theme.dart';

enum AppButtonVariant { primary, secondary }

/// Styleum design system button with consistent styling and animations.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.secondary;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _handleTapDown(TapDownDetails details) {
    if (_isEnabled) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      HapticFeedback.mediumImpact();
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.variant == AppButtonVariant.primary;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: AppAnimations.fast,
        child: AnimatedContainer(
          duration: AppAnimations.normal,
          curve: AppAnimations.easeOut,
          width: widget.fullWidth ? double.infinity : null,
          height: 56,
          decoration: BoxDecoration(
            color: isPrimary
                ? (_isPressed ? AppColors.cherryDark : AppColors.cherry)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: isPrimary
                ? null
                : Border.all(
                    color: _isPressed ? AppColors.cherry : AppColors.border,
                    width: 1.5,
                  ),
            boxShadow: isPrimary && _isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.cherry.withValues(alpha: _isPressed ? 0.5 : 0.4),
                      blurRadius: _isPressed ? 28 : 24,
                      offset: Offset(0, _isPressed ? 6 : 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isPrimary ? Colors.white : AppColors.cherry,
                    ),
                  )
                : Row(
                    mainAxisSize:
                        widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: isPrimary
                              ? Colors.white
                              : (_isPressed
                                  ? AppColors.cherry
                                  : AppColors.textPrimary),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isPrimary
                              ? Colors.white
                              : (_isPressed
                                  ? AppColors.cherry
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
