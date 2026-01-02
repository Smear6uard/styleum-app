import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:styleum/theme/theme.dart';

enum AppButtonVariant { primary, secondary, tertiary }

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

  const AppButton.tertiary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.tertiary;

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
    final isSecondary = widget.variant == AppButtonVariant.secondary;
    final isTertiary = widget.variant == AppButtonVariant.tertiary;

    // Determine colors based on variant
    Color getBackgroundColor() {
      if (isPrimary) {
        return _isPressed ? const Color(0xFF0F0F0F) : AppColors.textPrimary;
      }
      return Colors.transparent;
    }

    Color getTextColor() {
      if (isPrimary) return Colors.white;
      if (isSecondary) return AppColors.slateDark;
      return AppColors.textMuted; // tertiary
    }

    Border? getBorder() {
      if (isSecondary) {
        return Border.all(
          color: _isPressed ? AppColors.slateDark : AppColors.border,
          width: 1.5,
        );
      }
      return null;
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: AppAnimations.fast,
        child: AnimatedContainer(
          duration: AppAnimations.normal,
          curve: AppAnimations.easeOut,
          width: widget.fullWidth ? double.infinity : null,
          height: isTertiary ? null : 50,
          padding: isTertiary
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
              : null,
          decoration: BoxDecoration(
            color: getBackgroundColor(),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: getBorder(),
            boxShadow: isPrimary && _isEnabled
                ? const [AppShadows.primaryButton]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isPrimary ? Colors.white : getTextColor(),
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
                          color: getTextColor(),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: isTertiary ? 14 : 16,
                          fontWeight: isTertiary ? FontWeight.w500 : FontWeight.w600,
                          color: getTextColor(),
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
