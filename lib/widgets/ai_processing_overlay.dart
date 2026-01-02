import 'dart:async';
import 'package:flutter/material.dart';
import 'package:styleum/theme/theme.dart';

/// Cinematic AI processing overlay with rotating narrative text.
///
/// Used during:
/// - Analyzing clothes
/// - Removing background / prettify
/// - Generating outfits
class AIProcessingOverlay extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onCancel;
  final List<String>? customMessages;

  const AIProcessingOverlay({
    super.key,
    required this.isVisible,
    this.onCancel,
    this.customMessages,
  });

  @override
  State<AIProcessingOverlay> createState() => _AIProcessingOverlayState();
}

class _AIProcessingOverlayState extends State<AIProcessingOverlay>
    with SingleTickerProviderStateMixin {
  static const List<String> _defaultMessages = [
    'Analyzing fabric and silhouette…',
    'Matching colors and proportions…',
    'Finding your best pairings…',
    'Building your wardrobe profile…',
  ];

  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _sheetBackground = Color(0xFF111111); // AppColors.darkSheet

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _textTimer;
  int _currentMessageIndex = 0;

  List<String> get _messages => widget.customMessages ?? _defaultMessages;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startTextRotation();
  }

  void _startTextRotation() {
    _textTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _messages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: widget.isVisible
          ? _buildOverlay()
          : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }

  Widget _buildOverlay() {
    return Container(
      key: const ValueKey('visible'),
      color: Colors.black.withValues(alpha: 0.4),
      child: Column(
        children: [
          const Spacer(flex: 3),
          Expanded(
            flex: 7,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _sheetBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    _buildSpinner(),
                    const SizedBox(height: 32),
                    _buildNarrativeText(),
                    const Spacer(),
                    _buildTipText(),
                    const SizedBox(height: 16),
                    if (widget.onCancel != null) _buildCancelButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinner() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.slate.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.slate),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNarrativeText() {
    return SizedBox(
      height: 48,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          _messages[_currentMessageIndex],
          key: ValueKey<int>(_currentMessageIndex),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTipText() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        'Tip: Natural light helps the AI see details better.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: widget.onCancel,
      style: TextButton.styleFrom(
        foregroundColor: _textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: const Text(
        'Cancel',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
