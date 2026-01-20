import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

/// A Gen Z inspired animated balance card with number counter animation,
/// color changes based on owe/owed status, gradient background, and emoji indicators.
class AnimatedBalanceCard extends StatefulWidget {
  final double balance;
  final String currencySymbol;
  final String? title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showEmoji;
  final bool compact;
  final Duration animationDuration;

  const AnimatedBalanceCard({
    super.key,
    required this.balance,
    this.currencySymbol = '\$',
    this.title,
    this.subtitle,
    this.onTap,
    this.showEmoji = true,
    this.compact = false,
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<AnimatedBalanceCard> createState() => _AnimatedBalanceCardState();
}

class _AnimatedBalanceCardState extends State<AnimatedBalanceCard>
    with TickerProviderStateMixin {
  late AnimationController _countController;
  late AnimationController _pulseController;
  late Animation<double> _countAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  double _previousBalance = 0;

  @override
  void initState() {
    super.initState();
    _previousBalance = 0;

    _countController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _setupAnimations();
    _countController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _setupAnimations() {
    _countAnimation = Tween<double>(
      begin: _previousBalance,
      end: widget.balance,
    ).animate(CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.linear,
    ));
  }

  @override
  void didUpdateWidget(AnimatedBalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.balance != widget.balance) {
      _previousBalance = oldWidget.balance;
      _countController.reset();
      _setupAnimations();
      _countController.forward();
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Gradient _getGradient(double balance) {
    if (balance > 0.01) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF00F5A0),
          Color(0xFF00D9FF),
        ],
      );
    } else if (balance < -0.01) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF4757),
          Color(0xFFFF6B35),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF6B7280),
        Color(0xFF9CA3AF),
      ],
    );
  }

  String _getStatusText(double balance) {
    if (balance > 0.01) return 'You get back';
    if (balance < -0.01) return 'You owe';
    return 'All settled up!';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_countAnimation, _pulseAnimation]),
      builder: (context, child) {
        final currentBalance = _countAnimation.value;
        final gradient = _getGradient(currentBalance);
        final emoji = AppTheme.getBalanceEmoji(currentBalance);
        final statusText = _getStatusText(currentBalance);

        Widget content = widget.compact
            ? _buildCompactContent(currentBalance, gradient, emoji)
            : _buildFullContent(currentBalance, gradient, emoji, statusText);

        if (widget.onTap != null) {
          content = GestureDetector(
            onTap: widget.onTap,
            child: content,
          );
        }

        return content;
      },
    );
  }

  Widget _buildCompactContent(double balance, Gradient gradient, String emoji) {
    final absBalance = balance.abs();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.neonGlow(
          balance > 0 ? AppTheme.accentPrimary : AppTheme.accentRed,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showEmoji) ...[
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
          ],
          Text(
            '${widget.currencySymbol}${absBalance.toStringAsFixed(2)}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullContent(
    double balance,
    Gradient gradient,
    String emoji,
    String statusText,
  ) {
    final absBalance = balance.abs();
    final isPositive = balance > 0.01;
    final isNegative = balance < -0.01;

    return Transform.scale(
      scale: (isPositive || isNegative) ? _pulseAnimation.value : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (isPositive
                      ? AppTheme.accentPrimary
                      : isNegative
                          ? AppTheme.accentRed
                          : AppTheme.settledColor)
                  .withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.bgCard.withOpacity(0.9),
                    AppTheme.bgCardLight.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: (isPositive
                          ? AppTheme.accentPrimary
                          : isNegative
                              ? AppTheme.accentRed
                              : AppTheme.settledColor)
                      .withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title != null)
                            Text(
                              widget.title!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          const SizedBox(height: 4),
                          _buildStatusChip(statusText, gradient),
                        ],
                      ),
                      if (widget.showEmoji)
                        _buildEmojiIndicator(emoji, gradient),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Balance amount with shimmer
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.8),
                          Colors.white,
                        ],
                        stops: [
                          _shimmerAnimation.value - 0.3,
                          _shimmerAnimation.value,
                          _shimmerAnimation.value + 0.3,
                        ].map((s) => s.clamp(0.0, 1.0)).toList(),
                      ).createShader(bounds);
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currencySymbol,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          absBalance.toStringAsFixed(2),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String text, Gradient gradient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEmojiIndicator(String emoji, Gradient gradient) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.bgCardLight.withOpacity(0.8),
            AppTheme.bgCard.withOpacity(0.6),
          ],
        ),
        border: Border.all(
          color: AppTheme.glassBorder,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }
}

/// Compact balance indicator for lists
class BalanceIndicator extends StatelessWidget {
  final double balance;
  final String currencySymbol;
  final bool showEmoji;

  const BalanceIndicator({
    super.key,
    required this.balance,
    this.currencySymbol = '\$',
    this.showEmoji = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getBalanceColor(balance);
    final emoji = AppTheme.getBalanceEmoji(balance);
    final absBalance = balance.abs();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showEmoji && balance.abs() > 0.01) ...[
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
        ],
        Text(
          balance.abs() < 0.01
              ? 'settled'
              : '${balance > 0 ? '+' : '-'}$currencySymbol${absBalance.toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
