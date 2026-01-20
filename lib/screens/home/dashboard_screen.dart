import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';
import '../../models/group_model.dart';
import '../../services/auth_service.dart';
import '../../services/groups_service.dart';
import '../../services/expenses_service.dart';
import '../groups/group_detail_screen.dart';
import '../groups/create_group_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../settlements/settle_up_screen.dart';

/// Dashboard screen - main home tab
/// Shows balance summary, quick actions, recent activity, and groups
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final auth = context.watch<AuthService>();
    final userId = auth.userId;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: AppTheme.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: StreamBuilder<List<GroupModel>>(
        stream: context.read<GroupsService>().streamGroups(userId),
        builder: (context, groupsSnapshot) {
          final groups = groupsSnapshot.data ?? [];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom app bar with greeting
              _buildSliverAppBar(auth),

              // Content
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),

                    // Balance summary card
                    _BalanceSummaryCard(groups: groups, userId: userId),

                    const SizedBox(height: 24),

                    // Quick actions
                    _QuickActionsRow(groups: groups),

                    const SizedBox(height: 32),

                    // Recent activity section
                    _RecentActivitySection(groups: groups, userId: userId),

                    const SizedBox(height: 32),

                    // Friends with balances section
                    _FriendsBalancesSection(groups: groups, userId: userId),

                    const SizedBox(height: 32),

                    // Groups section
                    _GroupsSection(groups: groups),

                    const SizedBox(height: 100), // Bottom padding
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(AuthService auth) {
    final user = auth.currentUser;
    final greeting = _getGreeting();
    final firstName = user?.displayName?.split(' ').first ??
        user?.email.split('@').first ??
        'there';

    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.bgPrimary,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting,',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
            Row(
              children: [
                Text(
                  firstName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '\u{1F44B}', // Wave emoji
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ],
        ),
        expandedTitleScale: 1.0,
      ),
      actions: [
        // Notification bell (placeholder)
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications coming soon!'),
                backgroundColor: AppTheme.bgCard,
              ),
            );
          },
          icon: Stack(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: AppTheme.textSecondary,
              ),
              // Notification badge
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentPink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Balance summary card with gradient background
class _BalanceSummaryCard extends StatelessWidget {
  final List<GroupModel> groups;
  final String userId;

  const _BalanceSummaryCard({
    required this.groups,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BalanceSummary>(
      future: _calculateTotalBalance(context),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? _BalanceSummary(0, 0);

        return AnimatedListItem(
          index: 0,
          child: PressableScale(
            onTap: () => _showBalanceBreakdown(context, summary),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.bgSecondary,
                    AppTheme.bgTertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.accentPrimary.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentPrimary.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Total Balance',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Net balance amount
                  _buildNetBalance(summary),
                  const SizedBox(height: 16),
                  // Breakdown row
                  Row(
                    children: [
                      // You owe
                      Expanded(
                        child: _buildBalanceItem(
                          label: 'You owe',
                          amount: summary.youOwe,
                          color: AppTheme.owesColor,
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      // You're owed
                      Expanded(
                        child: _buildBalanceItem(
                          label: "You're owed",
                          amount: summary.youreOwed,
                          color: AppTheme.getBackColor,
                          icon: Icons.arrow_downward_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNetBalance(_BalanceSummary summary) {
    final netBalance = summary.youreOwed - summary.youOwe;
    final isPositive = netBalance >= 0;
    final color = netBalance > 0.01
        ? AppTheme.getBackColor
        : netBalance < -0.01
            ? AppTheme.owesColor
            : AppTheme.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPositive ? '+' : '-',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              '\$${netBalance.abs().toStringAsFixed(2)}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          netBalance > 0.01
              ? "Overall, you're owed money"
              : netBalance < -0.01
                  ? 'Overall, you owe money'
                  : "You're all settled up!",
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceItem({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<_BalanceSummary> _calculateTotalBalance(BuildContext context) async {
    double youOwe = 0;
    double youreOwed = 0;

    final groupsService = context.read<GroupsService>();

    for (final group in groups) {
      try {
        final members = await groupsService.getMembers(group.id);
        final myMember = members.where((m) => m.userId == userId).firstOrNull;

        if (myMember != null) {
          if (myMember.balance > 0.01) {
            youreOwed += myMember.balance;
          } else if (myMember.balance < -0.01) {
            youOwe += myMember.balance.abs();
          }
        }
      } catch (e) {
        debugPrint('Error calculating balance for group ${group.id}: $e');
      }
    }

    return _BalanceSummary(youOwe, youreOwed);
  }

  void _showBalanceBreakdown(BuildContext context, _BalanceSummary summary) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Balance Breakdown',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _BreakdownTile(
              icon: Icons.arrow_upward_rounded,
              iconColor: AppTheme.owesColor,
              label: 'You owe others',
              amount: summary.youOwe,
            ),
            const SizedBox(height: 12),
            _BreakdownTile(
              icon: Icons.arrow_downward_rounded,
              iconColor: AppTheme.getBackColor,
              label: 'Others owe you',
              amount: summary.youreOwed,
            ),
            const SizedBox(height: 20),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Balance',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '\$${(summary.youreOwed - summary.youOwe).toStringAsFixed(2)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: summary.youreOwed >= summary.youOwe
                        ? AppTheme.getBackColor
                        : AppTheme.owesColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double amount;

  const _BreakdownTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSummary {
  final double youOwe;
  final double youreOwed;

  _BalanceSummary(this.youOwe, this.youreOwed);
}

/// Quick actions row with gradient buttons
class _QuickActionsRow extends StatelessWidget {
  final List<GroupModel> groups;

  const _QuickActionsRow({required this.groups});

  @override
  Widget build(BuildContext context) {
    return AnimatedListItem(
      index: 1,
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.add_rounded,
              label: 'Add Expense',
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPrimary,
                  AppTheme.accentPrimary.withOpacity(0.8),
                ],
              ),
              onTap: () => _handleAddExpense(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.handshake_rounded,
              label: 'Settle Up',
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentBlue,
                  AppTheme.accentBlue.withOpacity(0.8),
                ],
              ),
              onTap: () => _handleSettleUp(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.document_scanner_rounded,
              label: 'Scan',
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPurple,
                  AppTheme.accentPurple.withOpacity(0.8),
                ],
              ),
              onTap: () => _handleScanReceipt(context),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAddExpense(BuildContext context) {
    HapticFeedback.lightImpact();

    if (groups.isEmpty) {
      _showCreateGroupPrompt(context);
      return;
    }

    if (groups.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(group: groups.first),
        ),
      );
      return;
    }

    // Show group selection
    _showGroupSelection(context, 'Add expense to', (group) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(group: group),
        ),
      );
    });
  }

  void _handleSettleUp(BuildContext context) {
    HapticFeedback.lightImpact();

    if (groups.isEmpty) {
      _showCreateGroupPrompt(context);
      return;
    }

    if (groups.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettleUpScreen(group: groups.first),
        ),
      );
      return;
    }

    _showGroupSelection(context, 'Settle up in', (group) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettleUpScreen(group: group),
        ),
      );
    });
  }

  void _handleScanReceipt(BuildContext context) {
    HapticFeedback.lightImpact();

    if (groups.isEmpty) {
      _showCreateGroupPrompt(context);
      return;
    }

    // Navigate to add expense with scan mode
    if (groups.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(group: groups.first),
        ),
      );
      return;
    }

    _showGroupSelection(context, 'Scan receipt for', (group) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(group: group),
        ),
      );
    });
  }

  void _showCreateGroupPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Create a Group First',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'You need to create a group before you can add expenses.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              );
            },
            child: const Text('Create Group'),
          ),
        ],
      ),
    );
  }

  void _showGroupSelection(
    BuildContext context,
    String title,
    Function(GroupModel) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...groups.map((group) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: group.themeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      group.icon,
                      color: group.themeColor,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    group.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${group.memberCount} member${group.memberCount != 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppTheme.textMuted,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(group);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent activity section
class _RecentActivitySection extends StatelessWidget {
  final List<GroupModel> groups;
  final String userId;

  const _RecentActivitySection({
    required this.groups,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

    return AnimatedListItem(
      index: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Recent Activity',
            onViewAll: () {
              // TODO: Navigate to full activity screen
            },
          ),
          const SizedBox(height: 16),
          // Show recent expenses from all groups
          FutureBuilder<List<_ActivityItem>>(
            future: _getRecentActivity(context),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: AppTheme.accentPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 40,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No recent activity',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add an expense to get started',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textDim,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: activities
                      .take(5)
                      .map((activity) => _ActivityTile(activity: activity))
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<_ActivityItem>> _getRecentActivity(BuildContext context) async {
    // This is a placeholder - in production you'd fetch from ExpensesService
    // across all groups and merge/sort by date
    final List<_ActivityItem> activities = [];

    // For now, return empty list - the UI handles empty state gracefully
    // A full implementation would:
    // 1. Fetch recent expenses from each group
    // 2. Merge and sort by date
    // 3. Map to _ActivityItem format
    return activities;
  }
}

class _ActivityItem {
  final String id;
  final String groupName;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final bool isSettlement;

  _ActivityItem({
    required this.id,
    required this.groupName,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.isSettlement = false,
  });
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.getCategoryColor(activity.category).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              AppTheme.getCategoryIcon(activity.category),
              color: AppTheme.getCategoryColor(activity.category),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
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
                  activity.groupName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${activity.amount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _formatDate(activity.date),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}';
  }
}

/// Friends with balances - horizontal scroll
class _FriendsBalancesSection extends StatelessWidget {
  final List<GroupModel> groups;
  final String userId;

  const _FriendsBalancesSection({
    required this.groups,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedListItem(
      index: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Friends',
            onViewAll: () {
              // Switch to Friends tab
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<_FriendBalance>>(
            future: _getFriendBalances(context),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final friends = snapshot.data ?? [];

              if (friends.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.accentPrimary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.person_add_rounded,
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No friends yet',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Create a group and add members',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: friends.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _FriendBalanceCard(friend: friends[index]);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<_FriendBalance>> _getFriendBalances(BuildContext context) async {
    final groupsService = context.read<GroupsService>();
    final Map<String, _FriendBalance> friendsMap = {};

    for (final group in groups) {
      try {
        final members = await groupsService.getMembers(group.id);
        for (final member in members) {
          if (member.userId != userId && member.userId != null) {
            final key = member.userId!;
            if (friendsMap.containsKey(key)) {
              friendsMap[key] = _FriendBalance(
                id: key,
                name: member.nickname,
                balance: friendsMap[key]!.balance + member.balance,
                initials: member.initials,
              );
            } else {
              friendsMap[key] = _FriendBalance(
                id: key,
                name: member.nickname,
                balance: member.balance,
                initials: member.initials,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting friend balances: $e');
      }
    }

    return friendsMap.values.toList();
  }
}

class _FriendBalance {
  final String id;
  final String name;
  final double balance;
  final String initials;

  _FriendBalance({
    required this.id,
    required this.name,
    required this.balance,
    required this.initials,
  });
}

class _FriendBalanceCard extends StatelessWidget {
  final _FriendBalance friend;

  const _FriendBalanceCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    final balanceColor = AppTheme.getBalanceColor(friend.balance);

    return PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        // TODO: Navigate to friend details or add expense with them
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: balanceColor.withOpacity(0.15),
              child: Text(
                friend.initials,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: balanceColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              friend.name.split(' ').first,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              friend.balance.abs() < 0.01
                  ? 'Settled'
                  : '${friend.balance > 0 ? '+' : '-'}\$${friend.balance.abs().toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: balanceColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Groups section
class _GroupsSection extends StatelessWidget {
  final List<GroupModel> groups;

  const _GroupsSection({required this.groups});

  @override
  Widget build(BuildContext context) {
    return AnimatedListItem(
      index: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Your Groups',
            onViewAll: () {
              // Switch to Groups tab
            },
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            _buildEmptyGroups(context)
          else
            Column(
              children: groups
                  .take(3)
                  .map((group) => _GroupTile(group: group))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyGroups(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.bgCard,
              AppTheme.bgCardLight,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accentPrimary.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppTheme.accentPrimary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create your first group',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start splitting expenses with friends',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.accentPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final GroupModel group;

  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(group: group),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: group.themeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  group.icon,
                  color: group.themeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.memberCount} member${group.memberCount != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.totalExpenses > 0)
                Text(
                  group.formatAmount(group.totalExpenses),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header with view all button
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({
    required this.title,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        if (onViewAll != null)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onViewAll?.call();
            },
            child: Row(
              children: [
                Text(
                  'See All',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppTheme.accentPrimary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
