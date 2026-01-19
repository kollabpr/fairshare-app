import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/group_model.dart';
import '../../models/group_member_model.dart';
import '../../models/settlement_model.dart';
import '../../services/groups_service.dart';
import '../../services/splitting_service.dart';
import '../../services/expenses_service.dart';
import '../../widgets/widgets.dart';
import 'record_payment_screen.dart';

/// Screen showing balances and settlement suggestions
class SettleUpScreen extends StatelessWidget {
  final GroupModel group;

  const SettleUpScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: Text('Settle Up'),
        backgroundColor: AppTheme.bgPrimary,
      ),
      body: StreamBuilder<List<GroupMemberModel>>(
        stream: context.read<GroupsService>().streamMembers(group.id),
        builder: (context, membersSnapshot) {
          if (membersSnapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading balances...');
          }

          final members = membersSnapshot.data ?? [];
          if (members.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No members',
              message: 'Add members to this group to start tracking expenses',
            );
          }

          // Calculate simplified debts
          final balances = <String, double>{};
          for (final member in members) {
            balances[member.id] = member.balance;
          }

          final splittingService = context.read<SplittingService>();
          final simplifiedDebts = splittingService.simplifyDebts(balances);

          // Check if all settled
          final hasDebts = simplifiedDebts.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              _buildSummaryCard(members, hasDebts),
              const SizedBox(height: 24),

              // Member balances section
              Text(
                'Individual Balances',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...members.map((member) => _MemberBalanceCard(
                member: member,
                currencySymbol: group.currencySymbol,
              )),

              // Suggested settlements
              if (simplifiedDebts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Suggested Settlements',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Optimized payments to minimize transactions',
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...simplifiedDebts.map((debt) {
                  final fromMember = members.firstWhere(
                    (m) => m.id == debt.fromMemberId,
                    orElse: () => GroupMemberModel(
                      id: '',
                      nickname: 'Unknown',
                      joinedAt: DateTime.now(),
                    ),
                  );
                  final toMember = members.firstWhere(
                    (m) => m.id == debt.toMemberId,
                    orElse: () => GroupMemberModel(
                      id: '',
                      nickname: 'Unknown',
                      joinedAt: DateTime.now(),
                    ),
                  );

                  return SettlementSuggestionTile(
                    debt: debt,
                    fromMember: fromMember,
                    toMember: toMember,
                    currencySymbol: group.currencySymbol,
                    onSettle: () => _recordPayment(
                      context,
                      fromMember,
                      toMember,
                      debt.amount,
                    ),
                  );
                }),
              ],

              // Settlement history
              const SizedBox(height: 24),
              _SettlementHistory(groupId: group.id, members: members),

              const SizedBox(height: 100), // FAB padding
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRecordPayment(context),
        icon: const Icon(Icons.payment_rounded),
        label: const Text('Record Payment'),
        backgroundColor: AppTheme.accentPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryCard(List<GroupMemberModel> members, bool hasDebts) {
    final totalOwed = members
        .where((m) => m.balance < 0)
        .fold(0.0, (sum, m) => sum + m.balance.abs());

    return GlassCard(
      glowColor: hasDebts ? AppTheme.warningColor : AppTheme.successColor,
      child: Column(
        children: [
          Icon(
            hasDebts ? Icons.account_balance_wallet_outlined : Icons.check_circle_outline,
            size: 48,
            color: hasDebts ? AppTheme.warningColor : AppTheme.successColor,
          ),
          const SizedBox(height: 16),
          Text(
            hasDebts ? 'Debts to Settle' : 'All Settled Up!',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (hasDebts) ...[
            const SizedBox(height: 8),
            Text(
              '${group.currencySymbol}${totalOwed.toStringAsFixed(2)} in outstanding debts',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Everyone in the group is settled',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _recordPayment(
    BuildContext context,
    GroupMemberModel from,
    GroupMemberModel to,
    double amount,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordPaymentScreen(
          group: group,
          preselectedFrom: from,
          preselectedTo: to,
          preselectedAmount: amount,
        ),
      ),
    );
  }

  void _openRecordPayment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordPaymentScreen(group: group),
      ),
    );
  }
}

/// Individual member balance card
class _MemberBalanceCard extends StatelessWidget {
  final GroupMemberModel member;
  final String currencySymbol;

  const _MemberBalanceCard({
    required this.member,
    this.currencySymbol = '\$',
  });

  @override
  Widget build(BuildContext context) {
    final balanceColor = AppTheme.getBalanceColor(member.balance);
    final balanceText = member.balance.abs() < 0.01
        ? 'Settled'
        : '${member.balance > 0 ? "gets back" : "owes"} $currencySymbol${member.balance.abs().toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: MemberAvatar(
          member: member,
          radius: 22,
          showBalance: true,
        ),
        title: Text(
          member.nickname,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: member.isGhostUser
            ? Text(
                'Not signed up yet',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: balanceColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: balanceColor.withOpacity(0.3)),
          ),
          child: Text(
            balanceText,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: balanceColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Settlement history section
class _SettlementHistory extends StatelessWidget {
  final String groupId;
  final List<GroupMemberModel> members;

  const _SettlementHistory({
    required this.groupId,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SettlementModel>>(
      stream: context.read<ExpensesService>().streamSettlements(groupId),
      builder: (context, snapshot) {
        final settlements = snapshot.data ?? [];

        if (settlements.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Settlements',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...settlements.take(5).map((settlement) {
              final fromMember = members.firstWhere(
                (m) => m.id == settlement.fromMemberId,
                orElse: () => GroupMemberModel(
                  id: '',
                  nickname: 'Unknown',
                  joinedAt: DateTime.now(),
                ),
              );
              final toMember = members.firstWhere(
                (m) => m.id == settlement.toMemberId,
                orElse: () => GroupMemberModel(
                  id: '',
                  nickname: 'Unknown',
                  joinedAt: DateTime.now(),
                ),
              );

              return SettlementCard(
                settlement: settlement,
                fromMember: fromMember,
                toMember: toMember,
                onConfirm: settlement.isConfirmed
                    ? null
                    : () => _confirmSettlement(context, settlement),
              );
            }),
          ],
        );
      },
    );
  }

  void _confirmSettlement(BuildContext context, SettlementModel settlement) {
    context.read<ExpensesService>().confirmSettlement(groupId, settlement.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment confirmed'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
