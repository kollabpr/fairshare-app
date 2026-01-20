import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';
import '../../models/friend_model.dart';
import '../../models/direct_expense_model.dart';
import '../../services/auth_service.dart';
import '../../services/friends_service.dart';
import '../../widgets/widgets.dart';
import 'add_direct_expense_screen.dart';
import 'direct_settle_up_screen.dart';

/// Screen showing all expenses and settlements with a specific friend
class FriendDetailScreen extends StatefulWidget {
  final FriendModel friend;

  const FriendDetailScreen({
    super.key,
    required this.friend,
  });

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  double _balance = 0;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _animController = AnimationController(
      vsync: this,
      duration: AppAnimations.standard,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: AppAnimations.enterCurve,
    );

    _animController.forward();
    _loadBalance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    setState(() => _isLoadingBalance = true);

    try {
      final authService = context.read<AuthService>();
      final friendsService = context.read<FriendsService>();

      final userId = authService.userId;
      if (userId == null) return;

      final balance = await friendsService.getFriendBalance(
        userId,
        widget.friend.friendUserId,
      );

      if (mounted) {
        setState(() {
          _balance = balance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading balance: $e');
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  void _navigateToAddExpense() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      AppAnimations.slideRoute(
        page: AddDirectExpenseScreen(friend: widget.friend),
      ),
    ).then((_) => _loadBalance());
  }

  void _navigateToSettleUp() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      AppAnimations.slideRoute(
        page: DirectSettleUpScreen(
          friend: widget.friend,
          balance: _balance,
        ),
      ),
    ).then((_) => _loadBalance());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App bar with friend info
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: AppTheme.bgPrimary,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.more_vert_rounded),
                  ),
                  onPressed: () => _showMoreOptions(),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeaderContent(),
              ),
            ),

            // Tab bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                tabController: _tabController,
              ),
            ),

            // Content based on tab
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExpensesTab(),
                  _buildSettlementsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  Widget _buildHeaderContent() {
    final balanceColor = AppTheme.getBalanceColor(_balance);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            balanceColor.withOpacity(0.15),
            AppTheme.bgPrimary,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
          child: Column(
            children: [
              // Friend avatar
              FriendAvatar(
                name: widget.friend.displayName,
                imageUrl: widget.friend.friendPhotoUrl,
                size: 70,
                showGradientRing: true,
                balance: _balance,
              ),
              const SizedBox(height: 14),

              // Friend name
              Text(
                widget.friend.displayName,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                widget.friend.friendEmail,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
              ),

              const SizedBox(height: 16),

              // Balance summary
              _isLoadingBalance
                  ? ShimmerPlaceholder(
                      width: 120,
                      height: 36,
                      borderRadius: 18,
                    )
                  : _buildBalanceSummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSummary() {
    final balanceColor = AppTheme.getBalanceColor(_balance);

    if (_balance.abs() < 0.01) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.settledColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.settledColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppTheme.settledColor,
            ),
            const SizedBox(width: 6),
            Text(
              'All settled up',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.settledColor,
              ),
            ),
          ],
        ),
      );
    }

    final isPositive = _balance > 0;
    final text = isPositive
        ? '${widget.friend.displayName} owes you'
        : 'You owe ${widget.friend.displayName}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: balanceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: balanceColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: balanceColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '\$${_balance.abs().toStringAsFixed(2)}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: balanceColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    final authService = context.read<AuthService>();
    final friendsService = context.read<FriendsService>();

    final userId = authService.userId;
    if (userId == null) {
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Not signed in',
      );
    }

    return StreamBuilder<List<DirectExpenseModel>>(
      stream: friendsService.streamDirectExpenses(
        userId,
        widget.friend.friendUserId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Loading expenses...');
        }

        final expenses = snapshot.data ?? [];

        if (expenses.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No expenses yet',
            message: 'Start splitting expenses with ${widget.friend.displayName}',
            actionLabel: 'Add Expense',
            onAction: _navigateToAddExpense,
          );
        }

        return RefreshIndicator(
          onRefresh: _loadBalance,
          color: AppTheme.accentPrimary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return AnimatedListItem(
                index: index,
                child: _DirectExpenseTile(
                  expense: expense,
                  currentUserId: userId,
                  friendName: widget.friend.displayName,
                  onTap: () => _showExpenseDetails(expense),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSettlementsTab() {
    final authService = context.read<AuthService>();
    final friendsService = context.read<FriendsService>();

    final userId = authService.userId;
    if (userId == null) {
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Not signed in',
      );
    }

    return StreamBuilder<List<DirectSettlementModel>>(
      stream: friendsService.streamDirectSettlements(
        userId,
        widget.friend.friendUserId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Loading settlements...');
        }

        final settlements = snapshot.data ?? [];

        if (settlements.isEmpty) {
          return EmptyState(
            icon: Icons.handshake_outlined,
            title: 'No settlements yet',
            message: 'Settle up when you have balances to clear',
          );
        }

        return RefreshIndicator(
          onRefresh: _loadBalance,
          color: AppTheme.accentPrimary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: settlements.length,
            itemBuilder: (context, index) {
              final settlement = settlements[index];
              return AnimatedListItem(
                index: index,
                child: _DirectSettlementTile(
                  settlement: settlement,
                  currentUserId: userId,
                  friendName: widget.friend.displayName,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Settle up button (only show if there's a balance)
        if (_balance.abs() >= 0.01)
          FloatingActionButton.small(
            heroTag: 'settle',
            onPressed: _navigateToSettleUp,
            backgroundColor: AppTheme.accentPurple,
            child: const Icon(Icons.handshake_rounded, size: 20),
          ),
        const SizedBox(height: 12),
        // Add expense button
        FloatingActionButton.extended(
          heroTag: 'addExpense',
          onPressed: _navigateToAddExpense,
          backgroundColor: AppTheme.accentPrimary,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'Add Expense',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _showExpenseDetails(DirectExpenseModel expense) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ExpenseDetailSheet(
        expense: expense,
        currentUserId: context.read<AuthService>().userId!,
        friendName: widget.friend.displayName,
      ),
    );
  }

  void _showMoreOptions() {
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
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_rounded, color: AppTheme.accentBlue),
              ),
              title: Text(
                'View Profile',
                style: GoogleFonts.inter(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to profile
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.notifications_rounded, color: AppTheme.accentOrange),
              ),
              title: Text(
                'Send Reminder',
                style: GoogleFonts.inter(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _sendReminder();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_remove_rounded, color: AppTheme.errorColor),
              ),
              title: Text(
                'Remove Friend',
                style: GoogleFonts.inter(color: AppTheme.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveFriend();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _sendReminder() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder sent to ${widget.friend.displayName}'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _confirmRemoveFriend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text(
          'Remove Friend',
          style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove ${widget.friend.displayName}? This will also delete all expense history between you.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement remove friend
            },
            child: Text(
              'Remove',
              style: GoogleFonts.inter(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab bar delegate for the friend detail screen
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;

  _TabBarDelegate({required this.tabController});

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.bgPrimary,
      child: TabBar(
        controller: tabController,
        labelColor: AppTheme.accentPrimary,
        unselectedLabelColor: AppTheme.textMuted,
        indicatorColor: AppTheme.accentPrimary,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'Expenses'),
          Tab(text: 'Settlements'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabController != oldDelegate.tabController;
  }
}

/// Tile for displaying a direct expense
class _DirectExpenseTile extends StatelessWidget {
  final DirectExpenseModel expense;
  final String currentUserId;
  final String friendName;
  final VoidCallback? onTap;

  const _DirectExpenseTile({
    required this.expense,
    required this.currentUserId,
    required this.friendName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final youPaid = expense.payerId == currentUserId;

    // Calculate what the current user owes/gets back using the model's method
    final userShare = expense.getBalanceForUser(currentUserId);

    final color = userShare >= 0 ? AppTheme.getBackColor : AppTheme.owesColor;
    final categoryColor = AppTheme.getCategoryColor(expense.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      categoryColor.withOpacity(0.2),
                      categoryColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: categoryColor.withOpacity(0.2)),
                ),
                child: Icon(
                  _getCategoryIcon(expense.category),
                  color: categoryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Description and date
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          youPaid ? 'You paid' : '$friendName paid',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          ' \$${expense.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(expense.date),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textDim,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Balance impact
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${userShare >= 0 ? '+' : ''}\$${userShare.abs().toStringAsFixed(2)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final icons = {
      'food': Icons.restaurant_rounded,
      'transport': Icons.directions_car_rounded,
      'shopping': Icons.shopping_bag_rounded,
      'entertainment': Icons.movie_rounded,
      'utilities': Icons.bolt_rounded,
      'rent': Icons.home_rounded,
      'travel': Icons.flight_rounded,
      'health': Icons.medical_services_rounded,
      'other': Icons.receipt_rounded,
    };
    return icons[category] ?? Icons.receipt_rounded;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// Tile for displaying a settlement
class _DirectSettlementTile extends StatelessWidget {
  final DirectSettlementModel settlement;
  final String currentUserId;
  final String friendName;

  const _DirectSettlementTile({
    required this.settlement,
    required this.currentUserId,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    final youPaid = settlement.fromUserId == currentUserId;
    final amount = settlement.amount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            // Settlement icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentPrimary.withOpacity(0.2),
                    AppTheme.accentPrimary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.handshake_rounded,
                color: AppTheme.accentPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Settlement info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    youPaid ? 'You paid $friendName' : '$friendName paid you',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (settlement.notes != null && settlement.notes!.isNotEmpty) ...[
                        Expanded(
                          child: Text(
                            settlement.notes!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _formatDate(settlement.date),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Amount
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// Bottom sheet showing expense details
class _ExpenseDetailSheet extends StatelessWidget {
  final DirectExpenseModel expense;
  final String currentUserId;
  final String friendName;

  const _ExpenseDetailSheet({
    required this.expense,
    required this.currentUserId,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    final youPaid = expense.payerId == currentUserId;
    final categoryColor = AppTheme.getCategoryColor(expense.category);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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

            // Header with icon and description
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        categoryColor.withOpacity(0.2),
                        categoryColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: categoryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _formatFullDate(expense.date),
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

            const SizedBox(height: 24),

            // Amount section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        '\$${expense.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paid by',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        youPaid ? 'You' : friendName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your share',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        '\$${expense.payerOwedAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$friendName\'s share',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        '\$${expense.participantOwedAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Notes section
            if (expense.notes != null && expense.notes!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Notes',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(
                  expense.notes!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Implement edit
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context),
                    icon: Icon(Icons.delete_rounded, color: AppTheme.errorColor),
                    label: Text(
                      'Delete',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppTheme.errorColor.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text(
          'Delete Expense',
          style: GoogleFonts.spaceGrotesk(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              // TODO: Implement delete
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final icons = {
      'food': Icons.restaurant_rounded,
      'transport': Icons.directions_car_rounded,
      'shopping': Icons.shopping_bag_rounded,
      'entertainment': Icons.movie_rounded,
      'utilities': Icons.bolt_rounded,
      'rent': Icons.home_rounded,
      'travel': Icons.flight_rounded,
      'health': Icons.medical_services_rounded,
      'other': Icons.receipt_rounded,
    };
    return icons[category] ?? Icons.receipt_rounded;
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
