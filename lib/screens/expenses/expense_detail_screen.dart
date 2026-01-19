import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/expense_model.dart';
import '../../models/split_model.dart';
import '../../models/group_model.dart';
import '../../models/group_member_model.dart';
import '../../services/expenses_service.dart';
import '../../services/groups_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';

/// Screen showing expense details with edit and delete options
class ExpenseDetailScreen extends StatefulWidget {
  final ExpenseModel expense;
  final GroupModel group;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    required this.group,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  List<SplitModel> _splits = [];
  List<GroupMemberModel> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final expensesService = context.read<ExpensesService>();
    final groupsService = context.read<GroupsService>();

    final splits = await expensesService.getSplits(
      widget.group.id,
      widget.expense.id,
    );
    final members = await groupsService.getMembers(widget.group.id);

    setState(() {
      _splits = splits;
      _members = members;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _canEditExpense();

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Expense Details'),
        backgroundColor: AppTheme.bgPrimary,
        actions: [
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editExpense,
              tooltip: 'Edit expense',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
              tooltip: 'Delete expense',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Main expense card
                _buildExpenseCard(),
                const SizedBox(height: 24),

                // Paid by section
                _buildPaidBySection(),
                const SizedBox(height: 24),

                // Splits section
                _buildSplitsSection(),

                // Notes section
                if (widget.expense.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 24),
                  _buildNotesSection(),
                ],

                // Receipt section
                if (widget.expense.receiptImageUrl != null) ...[
                  const SizedBox(height: 24),
                  _buildReceiptSection(),
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildExpenseCard() {
    return GlassCard(
      glowColor: AppTheme.getCategoryColor(widget.expense.category),
      child: Column(
        children: [
          // Category icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.getCategoryColor(widget.expense.category)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.expense.categoryIcon,
              color: AppTheme.getCategoryColor(widget.expense.category),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            widget.expense.description,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Amount
          Text(
            widget.expense.formattedAmount,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Date and category
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgTertiary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  widget.expense.categoryLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\u2022',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(width: 8),
              Text(
                widget.expense.formattedDate,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaidBySection() {
    final payer = _members.firstWhere(
      (m) => m.id == widget.expense.payerId,
      orElse: () => GroupMemberModel(
        id: '',
        nickname: 'Unknown',
        joinedAt: DateTime.now(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paid by',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: MemberAvatar(member: payer, radius: 22),
            title: Text(
              payer.nickname,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            trailing: Text(
              widget.expense.formattedAmount,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.getBackColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Split Details',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                widget.expense.splitType.name.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: _splits.map((split) {
              final member = _members.firstWhere(
                (m) => m.id == split.memberId,
                orElse: () => GroupMemberModel(
                  id: '',
                  nickname: 'Unknown',
                  joinedAt: DateTime.now(),
                ),
              );

              final isPayer = member.id == widget.expense.payerId;
              final netAmount = split.owedAmount - split.paidAmount;

              return ListTile(
                leading: MemberAvatar(member: member, radius: 18),
                title: Text(
                  member.nickname,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: isPayer
                    ? Text(
                        'Paid ${widget.expense.formattedAmount}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.getBackColor,
                        ),
                      )
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.expense.currencySymbol}${split.owedAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (netAmount.abs() > 0.01)
                      Text(
                        netAmount > 0
                            ? 'owes ${widget.expense.currencySymbol}${netAmount.abs().toStringAsFixed(2)}'
                            : 'gets back ${widget.expense.currencySymbol}${netAmount.abs().toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: netAmount > 0
                              ? AppTheme.owesColor
                              : AppTheme.getBackColor,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.expense.notes!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_outlined,
                color: AppTheme.accentPrimary,
              ),
            ),
            title: const Text('Receipt attached'),
            subtitle: const Text('Tap to view'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: _viewReceipt,
          ),
        ),
      ],
    );
  }

  bool _canEditExpense() {
    final userId = context.read<AuthService>().userId;
    final member = _members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => GroupMemberModel(
        id: '',
        nickname: '',
        joinedAt: DateTime.now(),
      ),
    );

    return widget.expense.createdBy == userId || member.isAdmin;
  }

  void _editExpense() {
    // TODO: Navigate to edit expense screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Are you sure you want to delete "${widget.expense.description}"? '
          'This will update all member balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExpense();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense() async {
    setState(() => _isLoading = true);

    final success = await context.read<ExpensesService>().deleteExpense(
      widget.group.id,
      widget.expense.id,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete expense'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _viewReceipt() {
    // TODO: Implement receipt viewer
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt viewer coming soon')),
    );
  }
}
