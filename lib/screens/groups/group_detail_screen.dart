import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/group_model.dart';
import '../../models/group_member_model.dart';
import '../../models/expense_model.dart';
import '../../services/groups_service.dart';
import '../../services/expenses_service.dart';
import '../../services/splitting_service.dart';
import '../../widgets/widgets.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/expense_detail_screen.dart';
import '../settlements/settle_up_screen.dart';
import 'group_settings_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: AppTheme.bgPrimary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.group.themeColor.withOpacity(0.3),
                        AppTheme.bgPrimary,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                      child: _buildGroupHeader(),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: _openSettings,
                ),
              ],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Expenses'),
                    Tab(text: 'Balances'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _ExpensesTab(groupId: widget.group.id, group: widget.group),
            _BalancesTab(groupId: widget.group.id, group: widget.group, onSettleUp: _openSettleUp),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        backgroundColor: AppTheme.accentPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildGroupHeader() {
    return StreamBuilder<List<GroupMemberModel>>(
      stream: context.read<GroupsService>().streamMembers(widget.group.id),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.group.themeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.group.icon,
                    color: widget.group.themeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${members.length} member${members.length != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Member avatars
            if (members.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: members.length > 5 ? 6 : members.length,
                  itemBuilder: (context, index) {
                    if (index == 5) {
                      return Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Center(
                          child: Text(
                            '+${members.length - 5}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      );
                    }

                    final member = members[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.accentPrimary.withOpacity(0.2),
                        child: Text(
                          member.initials,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _addExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(group: widget.group),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupSettingsScreen(group: widget.group),
      ),
    );
  }

  void _openSettleUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettleUpScreen(group: widget.group),
      ),
    );
  }
}

// Tab bar delegate for sticky tabs
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: AppTheme.bgPrimary,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

// Expenses tab
class _ExpensesTab extends StatelessWidget {
  final String groupId;
  final GroupModel group;

  const _ExpensesTab({required this.groupId, required this.group});

  void _openExpenseDetail(BuildContext context, ExpenseModel expense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseDetailScreen(expense: expense, group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExpenseModel>>(
      stream: context.read<ExpensesService>().streamExpenses(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentPrimary),
          );
        }

        final expenses = snapshot.data ?? [];

        if (expenses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to add\nyour first expense',
                    textAlign: TextAlign.center,
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            return ExpenseTile(
              expense: expense,
              onTap: () => _openExpenseDetail(context, expense),
            );
          },
        );
      },
    );
  }
}

// Balances tab
class _BalancesTab extends StatelessWidget {
  final String groupId;
  final GroupModel group;
  final VoidCallback? onSettleUp;

  const _BalancesTab({required this.groupId, required this.group, this.onSettleUp});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupMemberModel>>(
      stream: context.read<GroupsService>().streamMembers(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentPrimary),
          );
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
          return const Center(
            child: Text('No members'),
          );
        }

        // Calculate simplified debts
        final balances = <String, double>{};
        for (final member in members) {
          balances[member.id] = member.balance;
        }

        final splittingService = context.read<SplittingService>();
        final simplifiedDebts = splittingService.simplifyDebts(balances);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Settle up button
            if (simplifiedDebts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: onSettleUp,
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Settle Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

            // Member balances
            Text(
              'Member Balances',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ...members.map((member) => _MemberBalanceTile(member: member, currencySymbol: group.currencySymbol)),

            if (simplifiedDebts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Suggested Settlements',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ...simplifiedDebts.map((debt) => _SettlementSuggestion(
                debt: debt,
                members: members,
                currencySymbol: group.currencySymbol,
              )),
            ],
          ],
        );
      },
    );
  }
}

class _MemberBalanceTile extends StatelessWidget {
  final GroupMemberModel member;
  final String currencySymbol;

  const _MemberBalanceTile({required this.member, this.currencySymbol = '\$'});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentPrimary.withOpacity(0.2),
          child: Text(
            member.initials,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppTheme.accentPrimary,
            ),
          ),
        ),
        title: Text(
          member.nickname,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        trailing: BalanceBadge(balance: member.balance, currencySymbol: currencySymbol),
      ),
    );
  }
}

class _SettlementSuggestion extends StatelessWidget {
  final SimplifiedDebt debt;
  final List<GroupMemberModel> members;
  final String currencySymbol;

  const _SettlementSuggestion({
    required this.debt,
    required this.members,
    this.currencySymbol = '\$',
  });

  @override
  Widget build(BuildContext context) {
    final fromMember = members.firstWhere(
      (m) => m.id == debt.fromMemberId,
      orElse: () => GroupMemberModel(id: '', nickname: 'Unknown', joinedAt: DateTime.now()),
    );
    final toMember = members.firstWhere(
      (m) => m.id == debt.toMemberId,
      orElse: () => GroupMemberModel(id: '', nickname: 'Unknown', joinedAt: DateTime.now()),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.owesColor.withOpacity(0.2),
              child: Text(
                fromMember.initials,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.owesColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fromMember.nickname} pays ${toMember.nickname}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$currencySymbol${debt.amount.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentPrimary,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: AppTheme.accentGreen),
              onPressed: () {
                // TODO: Record settlement
              },
            ),
          ],
        ),
      ),
    );
  }
}
