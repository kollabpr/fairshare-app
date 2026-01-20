import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// A Gen Z inspired card with gradient border, glassmorphism effect,
/// and animated border option.
class GradientCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? width;
  final double? height;
  final Gradient? gradient;
  final bool animatedBorder;
  final Duration animationDuration;
  final double borderWidth;
  final VoidCallback? onTap;
  final bool enableGlow;
  final Color? glowColor;

  const GradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.width,
    this.height,
    this.gradient,
    this.animatedBorder = false,
    this.animationDuration = const Duration(seconds: 3),
    this.borderWidth = 2,
    this.onTap,
    this.enableGlow = true,
    this.glowColor,
  });

  @override
  State<GradientCard> createState() => _GradientCardState();
}

class _GradientCardState extends State<GradientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    if (widget.animatedBorder) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(GradientCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animatedBorder && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animatedBorder && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? AppTheme.purplePinkGradient;
    final glowColor = widget.glowColor ?? AppTheme.accentPurple;

    Widget cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius - widget.borderWidth),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: AppTheme.glassGradient,
            borderRadius: BorderRadius.circular(widget.borderRadius - widget.borderWidth),
            border: Border.all(
              color: AppTheme.glassBorder.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: widget.child,
        ),
      ),
    );

    Widget card;

    if (widget.animatedBorder) {
      card = AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: widget.enableGlow
                  ? [
                      BoxShadow(
                        color: Color.lerp(
                          AppTheme.accentPurple,
                          AppTheme.accentPink,
                          _rotationAnimation.value,
                        )!.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: CustomPaint(
              painter: _AnimatedGradientBorderPainter(
                progress: _rotationAnimation.value,
                borderRadius: widget.borderRadius,
                borderWidth: widget.borderWidth,
                colors: AppTheme.animatedBorderColors,
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.borderWidth),
                child: cardContent,
              ),
            ),
          );
        },
      );
    } else {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: effectiveGradient,
          boxShadow: widget.enableGlow
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.borderWidth),
          child: cardContent,
        ),
      );
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Custom painter for animated gradient border
class _AnimatedGradientBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final double borderWidth;
  final List<Color> colors;

  _AnimatedGradientBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.borderWidth,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    // Create rotating gradient
    final sweepGradient = SweepGradient(
      startAngle: progress * 2 * 3.14159,
      endAngle: (progress * 2 * 3.14159) + 2 * 3.14159,
      colors: colors,
      transform: GradientRotation(progress * 2 * 3.14159),
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_AnimatedGradientBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Simpler static gradient border card
class StaticGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? width;
  final double? height;
  final Gradient gradient;
  final double borderWidth;
  final VoidCallback? onTap;

  const StaticGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.width,
    this.height,
    this.gradient = AppTheme.purplePinkGradient,
    this.borderWidth = 2,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradient,
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth),
        padding: padding,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(borderRadius - borderWidth),
        ),
        child: child,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}
