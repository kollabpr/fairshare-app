import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';
import '../../models/recurring_expense_model.dart';
import '../../models/expense_model.dart';
import '../../services/auth_service.dart';
import '../../services/recurring_expense_service.dart';
import '../../widgets/widgets.dart';
import 'add_recurring_expense_screen.dart';

/// Screen showing all recurring expenses for the current user
class RecurringExpensesScreen extends StatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  State<RecurringExpensesScreen> createState() => _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppAnimations.standard,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: AppAnimations.enterCurve,
    );
    _animController.forward();

    // Generate any due expenses on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateDueExpenses();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _generateDueExpenses() async {
    final authService = context.read<AuthService>();
    final userId = authService.userId;
    if (userId == null) return;

    final recurringService = context.read<RecurringExpenseService>();
    final count = await recurringService.generateDueExpenses(userId);

    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated $count recurring expense${count > 1 ? 's' : ''}'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _navigateToAddScreen() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddRecurringExpenseScreen(),
      ),
    ).then((result) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurring expense created'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    });
  }

  void _editRecurringExpense(RecurringExpenseModel expense) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecurringExpenseScreen(existingExpense: expense),
      ),
    );
  }

  Future<void> _togglePause(RecurringExpenseModel expense) async {
    HapticFeedback.mediumImpact();
    final authService = context.read<AuthService>();
    final userId = authService.userId;
    if (userId == null) return;

    final recurringService = context.read<RecurringExpenseService>();
    bool success;

    if (expense.isActive) {
      success = await recurringService.pauseRecurringExpense(
        id: expense.id,
        groupId: expense.groupId,
        userId: userId,
      );
    } else {
      success = await recurringService.resumeRecurringExpense(
        id: expense.id,
        groupId: expense.groupId,
        userId: userId,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(expense.isActive ? 'Recurring expense paused' : 'Recurring expense resumed'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _deleteExpense(RecurringExpenseModel expense) async {
    HapticFeedback.heavyImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Recurring Expense',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${expense.description}"? This action cannot be undone.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authService = context.read<AuthService>();
    final userId = authService.userId;
    if (userId == null) return;

    final recurringService = context.read<RecurringExpenseService>();
    final success = await recurringService.deleteRecurringExpense(
      id: expense.id,
      groupId: expense.groupId,
      userId: userId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recurring expense deleted'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userId = authService.userId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        title: Text(
          'Recurring Expenses',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Generate due expenses',
            onPressed: _generateDueExpenses,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: StreamBuilder<List<RecurringExpenseModel>>(
          stream: context.read<RecurringExpenseService>().streamRecurringExpenses(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingIndicator(message: 'Loading recurring expenses...');
            }

            final expenses = snapshot.data ?? [];

            if (expenses.isEmpty) {
              return _buildEmptyState();
            }

            // Separate overdue, upcoming, and paused
            final overdue = expenses.where((e) => e.isActive && e.isOverdue).toList();
            final upcoming = expenses.where((e) => e.isActive && !e.isOverdue).toList();
            final paused = expenses.where((e) => !e.isActive).toList();

            return RefreshIndicator(
              onRefresh: _generateDueExpenses,
              color: AppTheme.accentPrimary,
              backgroundColor: AppTheme.bgCard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary card
                  _buildSummaryCard(expenses),
                  const SizedBox(height: 24),

                  // Overdue section
                  if (overdue.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Overdue',
                      overdue.length,
                      AppTheme.errorColor,
                      Icons.warning_rounded,
                    ),
                    const SizedBox(height: 12),
                    ...overdue.asMap().entries.map((entry) => AnimatedListItem(
                      index: entry.key,
                      child: _buildExpenseCard(entry.value, isOverdue: true),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Upcoming section
                  if (upcoming.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Active',
                      upcoming.length,
                      AppTheme.accentPrimary,
                      Icons.repeat_rounded,
                    ),
                    const SizedBox(height: 12),
                    ...upcoming.asMap().entries.map((entry) => AnimatedListItem(
                      index: entry.key + overdue.length,
                      child: _buildExpenseCard(entry.value),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Paused section
                  if (paused.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Paused',
                      paused.length,
                      AppTheme.textMuted,
                      Icons.pause_circle_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    ...paused.asMap().entries.map((entry) => AnimatedListItem(
                      index: entry.key + overdue.length + upcoming.length,
                      child: _buildExpenseCard(entry.value, isPaused: true),
                    )),
                  ],

                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddScreen,
        backgroundColor: AppTheme.accentPrimary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New Recurring',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Icon(
                Icons.repeat_rounded,
                size: 48,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No recurring expenses',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up expenses that repeat automatically.\nPerfect for rent, subscriptions, and bills.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToAddScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Recurring Expense'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<RecurringExpenseModel> expenses) {
    final activeExpenses = expenses.where((e) => e.isActive).toList();
    final totalMonthly = _calculateMonthlyTotal(activeExpenses);
    final overdueCount = expenses.where((e) => e.isActive && e.isOverdue).length;

    return GlassCard(
      glowColor: overdueCount > 0 ? AppTheme.errorColor : AppTheme.accentPrimary,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.neonGreenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.repeat_rounded,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Total',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      '\$${totalMonthly.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (overdueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        size: 16,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$overdueCount overdue',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                '${activeExpenses.length}',
                'Active',
                Icons.check_circle_outline_rounded,
                AppTheme.accentPrimary,
              ),
              _buildStatItem(
                '${expenses.where((e) => !e.isActive).length}',
                'Paused',
                Icons.pause_circle_outline_rounded,
                AppTheme.textMuted,
              ),
              _buildStatItem(
                '$overdueCount',
                'Overdue',
                Icons.warning_amber_rounded,
                AppTheme.errorColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  double _calculateMonthlyTotal(List<RecurringExpenseModel> expenses) {
    double total = 0;
    for (final expense in expenses) {
      switch (expense.frequency) {
        case RecurringFrequency.daily:
          total += expense.amount * 30;
          break;
        case RecurringFrequency.weekly:
          total += expense.amount * 4.33;
          break;
        case RecurringFrequency.biweekly:
          total += expense.amount * 2.17;
          break;
        case RecurringFrequency.monthly:
          total += expense.amount;
          break;
        case RecurringFrequency.yearly:
          total += expense.amount / 12;
          break;
      }
    }
    return total;
  }

  Widget _buildSectionHeader(String title, int count, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseCard(
    RecurringExpenseModel expense, {
    bool isOverdue = false,
    bool isPaused = false,
  }) {
    final categoryColor = AppTheme.getCategoryColor(expense.category);

    return Dismissible(
      key: Key(expense.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _editRecurringExpense(expense);
          return false;
        } else {
          _deleteExpense(expense);
          return false;
        }
      },
      child: PressableScale(
        onTap: () => _editRecurringExpense(expense),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverdue
                  ? AppTheme.errorColor.withOpacity(0.3)
                  : isPaused
                      ? AppTheme.borderColor
                      : AppTheme.borderColor,
            ),
            boxShadow: isOverdue
                ? [
                    BoxShadow(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Opacity(
            opacity: isPaused ? 0.6 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        expense.categoryIcon,
                        color: categoryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Description and frequency
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.description,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                expense.frequencyIcon,
                                size: 12,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                expense.frequencyDisplayName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              if (expense.isGroupExpense) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.group_outlined,
                                  size: 12,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Group',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          expense.formattedAmount,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        // Pause/Resume toggle
                        GestureDetector(
                          onTap: () => _togglePause(expense),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: expense.isActive
                                  ? AppTheme.bgCardLight
                                  : AppTheme.accentPrimary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  expense.isActive
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 14,
                                  color: expense.isActive
                                      ? AppTheme.textMuted
                                      : AppTheme.accentPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  expense.isActive ? 'Pause' : 'Resume',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: expense.isActive
                                        ? AppTheme.textMuted
                                        : AppTheme.accentPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Due date status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? AppTheme.errorColor.withOpacity(0.1)
                        : isPaused
                            ? AppTheme.bgCardLight
                            : AppTheme.accentPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.warning_rounded
                            : isPaused
                                ? Icons.pause_circle_outline_rounded
                                : Icons.schedule_rounded,
                        size: 14,
                        color: isOverdue
                            ? AppTheme.errorColor
                            : isPaused
                                ? AppTheme.textMuted
                                : AppTheme.accentPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        expense.dueStatusText,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isOverdue
                              ? AppTheme.errorColor
                              : isPaused
                                  ? AppTheme.textMuted
                                  : AppTheme.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
