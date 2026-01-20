import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/reports_service.dart';

/// Animated pie chart showing expenses by category
class CategoryPieChart extends StatefulWidget {
  final Map<String, CategorySpending> data;
  final double size;
  final bool showLegend;
  final ValueChanged<String?>? onCategorySelected;

  const CategoryPieChart({
    super.key,
    required this.data,
    this.size = 200,
    this.showLegend = true,
    this.onCategorySelected,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart>
    with SingleTickerProviderStateMixin {
  int? _touchedIndex;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Category colors matching the app theme
  static const Map<String, Color> categoryColors = {
    'food': AppTheme.accentOrange,
    'groceries': AppTheme.accentGreen,
    'transportation': AppTheme.accentBlue,
    'utilities': AppTheme.gradientBlueStart,
    'rent': AppTheme.accentPrimary,
    'entertainment': AppTheme.accentPurple,
    'shopping': AppTheme.accentPink,
    'travel': AppTheme.accentSecondary,
    'health': AppTheme.accentRed,
    'other': AppTheme.textMuted,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    return categoryColors[category.toLowerCase()] ?? AppTheme.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return _buildEmptyState();
    }

    // Sort by amount descending
    final sortedEntries = widget.data.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));

    return Column(
      children: [
        // Pie chart
        SizedBox(
          height: widget.size,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = null;
                          widget.onCategorySelected?.call(null);
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        if (_touchedIndex != null && _touchedIndex! < sortedEntries.length) {
                          widget.onCategorySelected?.call(sortedEntries[_touchedIndex!].key);
                        }
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: widget.size * 0.25,
                  sections: _buildSections(sortedEntries),
                ),
              );
            },
          ),
        ),

        // Legend
        if (widget.showLegend) ...[
          const SizedBox(height: 24),
          _buildLegend(sortedEntries),
        ],
      ],
    );
  }

  List<PieChartSectionData> _buildSections(
    List<MapEntry<String, CategorySpending>> entries,
  ) {
    return entries.asMap().entries.map((mapEntry) {
      final index = mapEntry.key;
      final entry = mapEntry.value;
      final isTouched = index == _touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? widget.size * 0.35 : widget.size * 0.3;
      final color = _getCategoryColor(entry.key);

      return PieChartSectionData(
        color: color,
        value: entry.value.amount * _animation.value,
        title: isTouched ? '${entry.value.percentage.toStringAsFixed(1)}%' : '',
        radius: radius,
        titleStyle: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
            ),
          ],
        ),
        badgeWidget: isTouched
            ? null
            : entry.value.percentage > 10
                ? _buildBadge(entry.value.percentage, color)
                : null,
        badgePositionPercentageOffset: 0.8,
      );
    }).toList();
  }

  Widget _buildBadge(double percentage, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '${percentage.toStringAsFixed(0)}%',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLegend(List<MapEntry<String, CategorySpending>> entries) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: entries.take(6).map((entry) {
        final color = _getCategoryColor(entry.key);
        final isSelected = entries.indexOf(entry) == _touchedIndex;

        return GestureDetector(
          onTap: () {
            setState(() {
              if (_touchedIndex == entries.indexOf(entry)) {
                _touchedIndex = null;
                widget.onCategorySelected?.call(null);
              } else {
                _touchedIndex = entries.indexOf(entry);
                widget.onCategorySelected?.call(entry.key);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color.withOpacity(0.5) : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalizeCategory(entry.key),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '\$${entry.value.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: widget.size,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No expense data',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalizeCategory(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }
}
