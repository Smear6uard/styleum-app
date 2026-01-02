import 'package:flutter/material.dart';
import 'package:styleum/theme/theme.dart';

/// Animated wrapper for list/grid items with staggered entrance animation.
///
/// Usage:
/// ```dart
/// GridView.builder(
///   itemBuilder: (context, index) {
///     return AnimatedListItem(
///       index: index,
///       child: MyCard(),
///     );
///   },
/// )
/// ```
class AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration? delay;
  final Duration? duration;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay,
    this.duration,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translateY;

  static const Duration _defaultDelay = Duration(milliseconds: 80);
  static const Duration _defaultDuration = AppAnimations.slow; // 300ms
  static const double _translateYDistance = 30.0; // 30px

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? _defaultDuration,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut),
    );

    _translateY = Tween<double>(
      begin: _translateYDistance, // 30px down
      end: 0.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut),
    );

    // Stagger delay based on index
    final delay = widget.delay ?? _defaultDelay;
    Future.delayed(delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _translateY.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Interactive card wrapper that lifts on press with shadow increase.
///
/// Usage:
/// ```dart
/// InteractiveCard(
///   onTap: () => navigateToDetail(),
///   child: MyCardContent(),
/// )
/// ```
class InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: AppAnimations.normal, // 200ms
        curve: AppAnimations.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: _isPressed ? 16 : 8,
              offset: Offset(0, _isPressed ? 6 : 2),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Animated wrapper for a single item that fades and slides in on first build.
/// Unlike AnimatedListItem, this doesn't use index-based staggering.
class AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final Duration? delay;
  final Duration? duration;

  const AnimatedEntrance({
    super.key,
    required this.child,
    this.delay,
    this.duration,
  });

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slidePosition;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppAnimations.slow,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut),
    );

    _slidePosition = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut),
    );

    if (widget.delay != null) {
      Future.delayed(widget.delay!, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: SlideTransition(
            position: _slidePosition,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
