import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/reports_service.dart';

/// Horizontal bar chart showing spending by group/friend
class SpendingBarChart extends StatefulWidget {
  final Map<String, GroupSpending> data;
  final double height;
  final ValueChanged<String?>? onBarSelected;

  const SpendingBarChart({
    super.key,
    required this.data,
    this.height = 250,
    this.onBarSelected,
  });

  @override
  State<SpendingBarChart> createState() => _SpendingBarChartState();
}

class _SpendingBarChartState extends State<SpendingBarChart>
    with SingleTickerProviderStateMixin {
  int? _touchedIndex;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Gradient colors for bars
  static const List<List<Color>> barGradients = [
    [AppTheme.accentPrimary, AppTheme.accentSecondary],
    [AppTheme.accentPurple, AppTheme.accentPink],
    [AppTheme.accentBlue, AppTheme.gradientBlueEnd],
    [AppTheme.accentOrange, AppTheme.accentYellow],
    [AppTheme.accentGreen, AppTheme.gradientGreenEnd],
    [AppTheme.accentRed, AppTheme.accentOrange],
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

  List<Color> _getBarGradient(int index) {
    return barGradients[index % barGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return _buildEmptyState();
    }

    // Sort by amount descending and take top 6
    final sortedEntries = widget.data.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));
    final displayedEntries = sortedEntries.take(6).toList();

    // Find max amount for scaling
    final maxAmount = displayedEntries.first.value.amount;

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Column(
            children: displayedEntries.asMap().entries.map((mapEntry) {
              final index = mapEntry.key;
              final entry = mapEntry.value;
              final isTouched = index == _touchedIndex;
              final percentage = maxAmount > 0 ? (entry.value.amount / maxAmount) : 0.0;
              final gradientColors = _getBarGradient(index);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_touchedIndex == index) {
                      _touchedIndex = null;
                      widget.onBarSelected?.call(null);
                    } else {
                      _touchedIndex = index;
                      widget.onBarSelected?.call(entry.key);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(isTouched ? 12 : 8),
                  decoration: BoxDecoration(
                    color: isTouched
                        ? gradientColors[0].withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isTouched
                          ? gradientColors[0].withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: gradientColors,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.value.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: isTouched ? FontWeight.w600 : FontWeight.w500,
                                      color: isTouched
                                          ? gradientColors[0]
                                          : AppTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${entry.value.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isTouched
                                      ? gradientColors[0]
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${entry.value.count} expense${entry.value.count != 1 ? 's' : ''}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      Stack(
                        children: [
                          // Background
                          Container(
                            height: isTouched ? 10 : 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppTheme.bgCardLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Fill
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: isTouched ? 10 : 8,
                            width: (MediaQuery.of(context).size.width - 80) *
                                percentage *
                                _animation.value,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradientColors,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: isTouched
                                  ? [
                                      BoxShadow(
                                        color: gradientColors[0].withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
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
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: widget.height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No group spending data',
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
}

/// Alternative: Vertical bar chart using fl_chart
class SpendingVerticalBarChart extends StatefulWidget {
  final Map<String, GroupSpending> data;
  final double height;

  const SpendingVerticalBarChart({
    super.key,
    required this.data,
    this.height = 200,
  });

  @override
  State<SpendingVerticalBarChart> createState() => _SpendingVerticalBarChartState();
}

class _SpendingVerticalBarChartState extends State<SpendingVerticalBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No data available',
            style: GoogleFonts.inter(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    final sortedEntries = widget.data.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));
    final displayedEntries = sortedEntries.take(5).toList();
    final maxY = displayedEntries.first.value.amount * 1.2;

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.bgCard,
                  tooltipBorder: BorderSide(color: AppTheme.borderLight),
                  tooltipRoundedRadius: 12,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final entry = displayedEntries[group.x.toInt()];
                    return BarTooltipItem(
                      '${entry.value.name}\n',
                      GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: '\$${entry.value.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: AppTheme.accentPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                touchCallback: (FlTouchEvent event, barTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        barTouchResponse == null ||
                        barTouchResponse.spot == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                  });
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= displayedEntries.length) return const SizedBox();
                      final name = displayedEntries[index].value.name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          name.length > 8 ? '${name.substring(0, 8)}...' : name,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: displayedEntries.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value.value;
                final isTouched = index == _touchedIndex;
                final gradients = _SpendingBarChartState.barGradients[index % _SpendingBarChartState.barGradients.length];

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data.amount * _animation.value,
                      gradient: LinearGradient(
                        colors: gradients,
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: isTouched ? 24 : 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: AppTheme.bgCardLight,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
