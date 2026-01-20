import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/reports_service.dart';

/// Line chart showing spending trend over time with gradient fill
class TrendLineChart extends StatefulWidget {
  final List<TimeSeriesDataPoint> data;
  final double height;
  final Color? lineColor;
  final bool showDots;
  final bool showGradient;

  const TrendLineChart({
    super.key,
    required this.data,
    this.height = 200,
    this.lineColor,
    this.showDots = true,
    this.showGradient = true,
  });

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
      return _buildEmptyState();
    }

    final lineColor = widget.lineColor ?? AppTheme.accentPrimary;
    final maxY = widget.data.map((e) => e.amount).reduce(math.max);
    final minY = 0.0;
    final yRange = maxY - minY;
    final adjustedMaxY = maxY + (yRange * 0.1); // Add 10% padding

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            children: [
              LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.bgCard,
                      tooltipBorder: BorderSide(color: AppTheme.borderLight),
                      tooltipRoundedRadius: 12,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final dataPoint = widget.data[spot.spotIndex];
                          return LineTooltipItem(
                            '${dataPoint.label}\n',
                            GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: '\$${dataPoint.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  color: lineColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                    touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.lineBarSpots == null ||
                            response.lineBarSpots!.isEmpty) {
                          _touchedIndex = null;
                          return;
                        }
                        _touchedIndex = response.lineBarSpots!.first.spotIndex;
                      });
                    },
                    handleBuiltInTouches: true,
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: adjustedMaxY / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.borderColor,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _calculateLabelInterval(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= widget.data.length) {
                            return const SizedBox();
                          }
                          // Only show some labels to avoid crowding
                          if (!_shouldShowLabel(index)) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              widget.data[index].label,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: adjustedMaxY / 4,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              _formatYAxisLabel(value),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (widget.data.length - 1).toDouble(),
                  minY: 0,
                  maxY: adjustedMaxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: widget.data.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.amount * _animation.value,
                        );
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: lineColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: widget.showDots,
                        getDotPainter: (spot, percent, barData, index) {
                          final isTouched = index == _touchedIndex;
                          return FlDotCirclePainter(
                            radius: isTouched ? 6 : 4,
                            color: isTouched ? lineColor : AppTheme.bgPrimary,
                            strokeWidth: 2,
                            strokeColor: lineColor,
                          );
                        },
                      ),
                      belowBarData: widget.showGradient
                          ? BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  lineColor.withOpacity(0.3 * _animation.value),
                                  lineColor.withOpacity(0.05 * _animation.value),
                                  lineColor.withOpacity(0.0),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            )
                          : BarAreaData(show: false),
                      shadow: Shadow(
                        color: lineColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ),
                  ],
                ),
              ),
              // Animated line drawing effect overlay
              if (_animation.value < 1)
                Positioned.fill(
                  child: ClipRect(
                    clipper: _LineClipper(_animation.value),
                    child: Container(color: AppTheme.bgPrimary),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _calculateLabelInterval() {
    if (widget.data.length <= 7) return 1;
    if (widget.data.length <= 14) return 2;
    if (widget.data.length <= 31) return 7;
    return (widget.data.length / 4).ceil().toDouble();
  }

  bool _shouldShowLabel(int index) {
    final interval = _calculateLabelInterval().toInt();
    if (widget.data.length <= 7) return true;
    if (index == 0 || index == widget.data.length - 1) return true;
    return index % interval == 0;
  }

  String _formatYAxisLabel(double value) {
    if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: widget.height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No trend data available',
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

/// Custom clipper for animated line drawing effect
class _LineClipper extends CustomClipper<Rect> {
  final double progress;

  _LineClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      size.width * progress,
      0,
      size.width * (1 - progress),
      size.height,
    );
  }

  @override
  bool shouldReclip(_LineClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

/// Mini sparkline chart for compact displays
class SparklineChart extends StatelessWidget {
  final List<double> data;
  final double height;
  final double width;
  final Color? lineColor;
  final bool showGradient;

  const SparklineChart({
    super.key,
    required this.data,
    this.height = 40,
    this.width = 100,
    this.lineColor,
    this.showGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height, width: width);

    final color = lineColor ?? AppTheme.accentPrimary;
    final maxY = data.reduce(math.max);
    final minY = data.reduce(math.min);
    final range = maxY - minY;
    final adjustedMaxY = maxY + (range * 0.1);
    final adjustedMinY = range > 0 ? minY - (range * 0.1) : 0.0;

    return SizedBox(
      height: height,
      width: width,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: adjustedMinY,
          maxY: adjustedMaxY,
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: showGradient
                  ? BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withOpacity(0.2),
                          color.withOpacity(0.0),
                        ],
                      ),
                    )
                  : BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
