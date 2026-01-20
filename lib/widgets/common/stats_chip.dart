import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

/// A Gen Z inspired compact stats chip with icon, number, and label.
/// Can have gradient or solid background.
class StatsChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final Gradient? gradient;
  final bool compact;
  final VoidCallback? onTap;
  final bool showTrend;
  final double? trendValue;
  final bool trendUp;

  const StatsChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
    this.gradient,
    this.compact = false,
    this.onTap,
    this.showTrend = false,
    this.trendValue,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.accentPrimary;

    Widget content = compact
        ? _buildCompactContent(effectiveColor)
        : _buildFullContent(effectiveColor);

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildCompactContent(Color effectiveColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? effectiveColor.withOpacity(0.15) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: effectiveColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: gradient != null ? Colors.white : effectiveColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: gradient != null
                  ? Colors.white.withOpacity(0.8)
                  : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullContent(Color effectiveColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppTheme.bgCard : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gradient != null
              ? Colors.white.withOpacity(0.1)
              : effectiveColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: gradient != null
            ? [
                BoxShadow(
                  color: (gradient as LinearGradient).colors.first.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: gradient != null
                      ? Colors.white.withOpacity(0.2)
                      : effectiveColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: gradient != null ? Colors.white : effectiveColor,
                ),
              ),
              if (showTrend && trendValue != null) ...[
                const Spacer(),
                _buildTrendIndicator(),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: gradient != null ? Colors.white : AppTheme.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: gradient != null
                  ? Colors.white.withOpacity(0.7)
                  : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator() {
    final trendColor = trendUp ? AppTheme.successColor : AppTheme.errorColor;
    final trendIcon = trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 14, color: trendColor),
          const SizedBox(width: 2),
          Text(
            '${trendValue!.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of stats chips
class StatsChipRow extends StatelessWidget {
  final List<StatsChipData> stats;
  final bool compact;
  final double spacing;

  const StatsChipRow({
    super.key,
    required this.stats,
    this.compact = true,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: stats.map((stat) {
          return Padding(
            padding: EdgeInsets.only(right: spacing),
            child: StatsChip(
              icon: stat.icon,
              value: stat.value,
              label: stat.label,
              color: stat.color,
              gradient: stat.gradient,
              compact: compact,
              onTap: stat.onTap,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A grid of stats chips
class StatsChipGrid extends StatelessWidget {
  final List<StatsChipData> stats;
  final int crossAxisCount;
  final double spacing;

  const StatsChipGrid({
    super.key,
    required this.stats,
    this.crossAxisCount = 2,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1.4,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return StatsChip(
          icon: stat.icon,
          value: stat.value,
          label: stat.label,
          color: stat.color,
          gradient: stat.gradient,
          compact: false,
          onTap: stat.onTap,
          showTrend: stat.showTrend,
          trendValue: stat.trendValue,
          trendUp: stat.trendUp,
        );
      },
    );
  }
}

/// Data class for stats chip
class StatsChipData {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final bool showTrend;
  final double? trendValue;
  final bool trendUp;

  const StatsChipData({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
    this.gradient,
    this.onTap,
    this.showTrend = false,
    this.trendValue,
    this.trendUp = true,
  });
}

/// Mini stat badge for compact displays
class MiniStatBadge extends StatelessWidget {
  final String value;
  final Color? color;
  final IconData? icon;

  const MiniStatBadge({
    super.key,
    required this.value,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.accentPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular progress stat
class CircularStatIndicator extends StatelessWidget {
  final double progress;
  final String label;
  final String value;
  final Color? color;
  final double size;

  const CircularStatIndicator({
    super.key,
    required this.progress,
    required this.label,
    required this.value,
    this.color,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.accentPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 6,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: AlwaysStoppedAnimation(AppTheme.borderColor),
                ),
              ),
              // Progress circle
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(effectiveColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Value text
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
