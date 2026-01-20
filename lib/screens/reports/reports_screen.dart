import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';
import '../../services/auth_service.dart';
import '../../services/reports_service.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/charts/category_pie_chart.dart';
import '../../widgets/charts/spending_bar_chart.dart';
import '../../widgets/charts/trend_line_chart.dart';

/// Reports screen with charts and analytics
/// Splitwise-like analytics view for expense insights
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late ReportsService _reportsService;
  TimePeriod _selectedPeriod = TimePeriod.thisMonth;

  // Data state
  SpendingSummary? _summary;
  Map<String, CategorySpending> _categoryData = {};
  Map<String, GroupSpending> _groupData = {};
  List<TimeSeriesDataPoint> _trendData = [];
  List<TopExpenseItem> _topExpenses = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reportsService = ReportsService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    final userId = auth.userId;

    if (userId == null) {
      setState(() {
        _error = 'User not logged in';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateRange = _reportsService.getDateRange(_selectedPeriod);

      // Load all data in parallel
      final results = await Future.wait([
        _reportsService.getSpendingSummary(userId, dateRange.start, dateRange.end),
        _reportsService.getSpendingByCategory(userId, dateRange.start, dateRange.end),
        _reportsService.getSpendingByGroup(userId, dateRange.start, dateRange.end),
        _reportsService.getSpendingOverTime(
          userId,
          dateRange.start,
          dateRange.end,
          _getGranularity(),
        ),
        _reportsService.getTopExpenses(
          userId,
          5,
          startDate: dateRange.start,
          endDate: dateRange.end,
        ),
      ]);

      setState(() {
        _summary = results[0] as SpendingSummary;
        _categoryData = results[1] as Map<String, CategorySpending>;
        _groupData = results[2] as Map<String, GroupSpending>;
        _trendData = results[3] as List<TimeSeriesDataPoint>;
        _topExpenses = results[4] as List<TopExpenseItem>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  TimeGranularity _getGranularity() {
    switch (_selectedPeriod) {
      case TimePeriod.thisMonth:
      case TimePeriod.lastMonth:
        return TimeGranularity.daily;
      case TimePeriod.thisYear:
        return TimeGranularity.monthly;
      case TimePeriod.allTime:
        return TimeGranularity.monthly;
    }
  }

  String _getPeriodLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.thisMonth:
        return 'This Month';
      case TimePeriod.lastMonth:
        return 'Last Month';
      case TimePeriod.thisYear:
        return 'This Year';
      case TimePeriod.allTime:
        return 'All Time';
    }
  }

  Future<void> _exportData() async {
    final auth = context.read<AuthService>();
    final userId = auth.userId;

    if (userId == null) return;

    HapticFeedback.lightImpact();

    try {
      final dateRange = _reportsService.getDateRange(_selectedPeriod);
      final csvData = await _reportsService.exportToCSV(
        userId,
        dateRange.start,
        dateRange.end,
      );

      // Get downloads directory or app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'fairshare_expenses_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csvData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported to $fileName',
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
            ),
            backgroundColor: AppTheme.bgCard,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: AppTheme.accentPrimary,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to export: $e',
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
            ),
            backgroundColor: AppTheme.errorColor.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          _buildAppBar(),

          // Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // Time period selector
                _buildPeriodSelector(),

                const SizedBox(height: 24),

                // Content based on loading state
                if (_isLoading)
                  _buildLoadingState()
                else if (_error != null)
                  _buildErrorState()
                else ...[
                  // Total spent card
                  _buildTotalSpentCard(),

                  const SizedBox(height: 24),

                  // Spending trend chart
                  _buildTrendSection(),

                  const SizedBox(height: 24),

                  // Category breakdown
                  _buildCategorySection(),

                  const SizedBox(height: 24),

                  // Group spending
                  _buildGroupSection(),

                  const SizedBox(height: 24),

                  // Top expenses
                  _buildTopExpensesSection(),

                  const SizedBox(height: 24),

                  // Export button
                  _buildExportButton(),

                  const SizedBox(height: 100),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.bgPrimary,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Row(
          children: [
            Icon(
              Icons.analytics_rounded,
              color: AppTheme.accentPrimary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Reports',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        expandedTitleScale: 1.0,
      ),
      actions: [
        IconButton(
          onPressed: _loadData,
          icon: Icon(
            Icons.refresh_rounded,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return AnimatedListItem(
      index: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: TimePeriod.values.map((period) {
            final isSelected = period == _selectedPeriod;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (period != _selectedPeriod) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedPeriod = period;
                    });
                    _loadData();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentPrimary.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentPrimary.withOpacity(0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getPeriodLabel(period).split(' ').last,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.accentPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const CircularProgressIndicator(
              color: AppTheme.accentPrimary,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading reports...',
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSpentCard() {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();

    return AnimatedListItem(
      index: 1,
      child: GlassCard(
        glowColor: AppTheme.accentPrimary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.payments_rounded,
                        size: 16,
                        color: AppTheme.accentPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total Spent',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Comparison badge
                if (summary.previousPeriodTotal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: summary.isIncrease
                          ? AppTheme.errorColor.withOpacity(0.15)
                          : AppTheme.accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          summary.isIncrease
                              ? Icons.trending_up_rounded
                              : summary.isDecrease
                                  ? Icons.trending_down_rounded
                                  : Icons.trending_flat_rounded,
                          size: 14,
                          color: summary.isIncrease
                              ? AppTheme.errorColor
                              : AppTheme.accentGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${summary.percentChange.abs().toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: summary.isIncrease
                                ? AppTheme.errorColor
                                : AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '\$${summary.totalSpent.toStringAsFixed(2)}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatChip(
                  icon: Icons.receipt_long_rounded,
                  label: '${summary.transactionCount} transactions',
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  icon: Icons.calendar_today_rounded,
                  label: '\$${summary.averagePerDay.toStringAsFixed(2)}/day',
                ),
              ],
            ),
            if (summary.previousPeriodTotal > 0) ...[
              const SizedBox(height: 12),
              Text(
                'vs \$${summary.previousPeriodTotal.toStringAsFixed(2)} previous period',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendSection() {
    return AnimatedListItem(
      index: 2,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spending Trend',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Icon(
                  Icons.show_chart_rounded,
                  color: AppTheme.accentSecondary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),
            TrendLineChart(
              data: _trendData,
              height: 200,
              lineColor: AppTheme.accentSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return AnimatedListItem(
      index: 3,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'By Category',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Icon(
                  Icons.pie_chart_rounded,
                  color: AppTheme.accentPurple,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),
            CategoryPieChart(
              data: _categoryData,
              size: 200,
              showLegend: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection() {
    return AnimatedListItem(
      index: 4,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'By Group',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Icon(
                  Icons.group_rounded,
                  color: AppTheme.accentBlue,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SpendingBarChart(
              data: _groupData,
              height: 280,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopExpensesSection() {
    if (_topExpenses.isEmpty) return const SizedBox.shrink();

    return AnimatedListItem(
      index: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Expenses',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Icon(
                  Icons.stars_rounded,
                  color: AppTheme.accentYellow,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              children: _topExpenses.asMap().entries.map((entry) {
                final index = entry.key;
                final expense = entry.value;
                final isLast = index == _topExpenses.length - 1;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(color: AppTheme.borderColor),
                          ),
                  ),
                  child: Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getRankGradient(index),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Category icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.getCategoryColor(expense.category)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          AppTheme.getCategoryIcon(expense.category),
                          color: AppTheme.getCategoryColor(expense.category),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.description,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              expense.groupName ?? 'Direct expense',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Amount
                      Text(
                        '\$${expense.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getRankGradient(int index) {
    switch (index) {
      case 0:
        return [AppTheme.accentYellow, AppTheme.accentOrange];
      case 1:
        return [AppTheme.textMuted, AppTheme.textDim];
      case 2:
        return [AppTheme.accentOrange, AppTheme.accentRed];
      default:
        return [AppTheme.bgCardLight, AppTheme.bgTertiary];
    }
  }

  Widget _buildExportButton() {
    return AnimatedListItem(
      index: 6,
      child: PressableScale(
        onTap: _exportData,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.download_rounded,
                color: AppTheme.accentPrimary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Export Data as CSV',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
