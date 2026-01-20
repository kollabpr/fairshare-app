import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';

/// A Gen Z inspired quick action button with gradient background,
/// glassmorphism, bounce animation, and icon with label.
class QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? iconColor;
  final bool enableBounce;
  final bool showGlow;
  final double size;
  final bool compact;
  final String? badge;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.gradient,
    this.iconColor,
    this.enableBounce = true,
    this.showGlow = true,
    this.size = 72,
    this.compact = false,
    this.badge,
  });

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _glowController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.9)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.05)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_bounceController);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.showGlow) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.enableBounce) {
      _bounceController.forward().then((_) {
        _bounceController.reverse();
      });
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? AppTheme.purplePinkGradient;
    final effectiveIconColor = widget.iconColor ?? Colors.white;

    return GestureDetector(
      onTap: widget.onTap != null ? _handleTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bounceAnimation, _glowAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.enableBounce ? _bounceAnimation.value : 1.0,
            child: widget.compact
                ? _buildCompactButton(effectiveGradient, effectiveIconColor)
                : _buildFullButton(effectiveGradient, effectiveIconColor),
          );
        },
      ),
    );
  }

  Widget _buildCompactButton(Gradient gradient, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: widget.showGlow
            ? [
                BoxShadow(
                  color: AppTheme.accentPurple.withOpacity(_glowAnimation.value),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullButton(Gradient gradient, Color iconColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Button with glassmorphism
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.size * 0.3),
                boxShadow: widget.showGlow
                    ? [
                        BoxShadow(
                          color: AppTheme.accentPurple
                              .withOpacity(_glowAnimation.value),
                          blurRadius: 25,
                          spreadRadius: -5,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.size * 0.3),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (gradient as LinearGradient).colors.first.withOpacity(0.8),
                          gradient.colors.last.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(widget.size * 0.3),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        color: iconColor,
                        size: widget.size * 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Badge
            if (widget.badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPink,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPink.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    widget.badge!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// A row of quick action buttons
class QuickActionRow extends StatelessWidget {
  final List<QuickActionData> actions;
  final double spacing;
  final double buttonSize;
  final bool scrollable;

  const QuickActionRow({
    super.key,
    required this.actions,
    this.spacing = 16,
    this.buttonSize = 64,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = actions
        .map((action) => QuickActionButton(
              icon: action.icon,
              label: action.label,
              onTap: action.onTap,
              gradient: action.gradient,
              size: buttonSize,
              badge: action.badge,
            ))
        .toList();

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: buttons
              .map((btn) => Padding(
                    padding: EdgeInsets.only(right: spacing),
                    child: btn,
                  ))
              .toList(),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: buttons,
    );
  }
}

/// Data class for quick action
class QuickActionData {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final String? badge;

  const QuickActionData({
    required this.icon,
    required this.label,
    this.onTap,
    this.gradient,
    this.badge,
  });
}

/// Floating action button with Gen Z style
class GenZFloatingActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final String? label;
  final bool extended;

  const GenZFloatingActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.gradient,
    this.label,
    this.extended = false,
  });

  @override
  State<GenZFloatingActionButton> createState() =>
      _GenZFloatingActionButtonState();
}

class _GenZFloatingActionButtonState extends State<GenZFloatingActionButton>
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

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? AppTheme.primaryGradient;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.extended ? 20 : 16,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                gradient: effectiveGradient,
                borderRadius: BorderRadius.circular(widget.extended ? 28 : 56),
                boxShadow: [
                  BoxShadow(
                    color: (effectiveGradient as LinearGradient)
                        .colors
                        .first
                        .withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 24),
                  if (widget.extended && widget.label != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.label!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
