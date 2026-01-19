import 'package:flutter/material.dart';

/// Apple-like smooth animations and transitions
class AppAnimations {
  // ============================================
  // DURATION CONSTANTS (Apple-style timing)
  // ============================================

  /// Fast interaction feedback (button press, etc.)
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions
  static const Duration standard = Duration(milliseconds: 300);

  /// Page transitions
  static const Duration pageTransition = Duration(milliseconds: 350);

  /// Slow, dramatic animations
  static const Duration slow = Duration(milliseconds: 500);

  /// Very slow for emphasis
  static const Duration emphasis = Duration(milliseconds: 700);

  // ============================================
  // CURVES (Apple-style easing)
  // ============================================

  /// Default iOS easing - smooth deceleration
  static const Curve defaultCurve = Curves.easeOutCubic;

  /// For elements entering view
  static const Curve enterCurve = Curves.easeOutQuart;

  /// For elements exiting view
  static const Curve exitCurve = Curves.easeInCubic;

  /// Bouncy spring effect (for emphasis)
  static const Curve bouncyCurve = Curves.elasticOut;

  /// Smooth spring (iOS default feel)
  static const Curve springCurve = Curves.easeOutBack;

  /// Linear for progress indicators
  static const Curve linearCurve = Curves.linear;

  // ============================================
  // PAGE ROUTE TRANSITIONS
  // ============================================

  /// iOS-style slide transition
  static PageRouteBuilder<T> slideRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: pageTransition,
      reverseTransitionDuration: pageTransition,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: enterCurve),
        );
        final offsetAnimation = animation.drive(tween);

        // Fade secondary page slightly
        final fadeAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: exitCurve),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// iOS-style fade and scale transition (for modals)
  static PageRouteBuilder<T> fadeScaleRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: standard,
      reverseTransitionDuration: standard,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: enterCurve,
        );
        final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: enterCurve),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
    );
  }

  // ============================================
  // WIDGET ANIMATIONS
  // ============================================

  /// Stagger delay for list items
  static Duration staggerDelay(int index, {int maxDelay = 5}) {
    final clampedIndex = index.clamp(0, maxDelay);
    return Duration(milliseconds: 50 * clampedIndex);
  }
}

/// Animated widget wrapper for list items with stagger effect
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration? delay;
  final Duration? duration;
  final Curve? curve;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay,
    this.duration,
    this.curve,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppAnimations.standard,
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: widget.curve ?? AppAnimations.enterCurve,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(curve);

    // Start animation after delay
    Future.delayed(
      widget.delay ?? AppAnimations.staggerDelay(widget.index),
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Animated press effect (like iOS buttons)
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
