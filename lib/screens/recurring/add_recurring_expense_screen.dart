import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';
import '../../models/recurring_expense_model.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/friend_model.dart';
import '../../services/auth_service.dart';
import '../../services/groups_service.dart';
import '../../services/friends_service.dart';
import '../../services/recurring_expense_service.dart';
import '../../widgets/widgets.dart';

/// Screen to create or edit a recurring expense
class AddRecurringExpenseScreen extends StatefulWidget {
  final RecurringExpenseModel? existingExpense;

  const AddRecurringExpenseScreen({
    super.key,
    this.existingExpense,
  });

  @override
  State<AddRecurringExpenseScreen> createState() => _AddRecurringExpenseScreenState();
}

class _AddRecurringExpenseScreenState extends State<AddRecurringExpenseScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Form state
  _ExpenseTarget _expenseTarget = _ExpenseTarget.group;
  GroupModel? _selectedGroup;
  FriendModel? _selectedFriend;
  String _selectedCategory = 'other';
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int _dayOfWeek = DateTime.now().weekday;
  int _dayOfMonth = DateTime.now().day;
  String _currencyCode = 'USD';
  SplitType _splitType = SplitType.equal;
  bool _isLoading = false;

  // For editing
  bool get _isEditing => widget.existingExpense != null;

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

    // Pre-fill if editing
    if (_isEditing) {
      final expense = widget.existingExpense!;
      _descriptionController.text = expense.description;
      _amountController.text = expense.amount.toStringAsFixed(2);
      _notesController.text = expense.notes ?? '';
      _selectedCategory = expense.category;
      _frequency = expense.frequency;
      _startDate = expense.startDate;
      _endDate = expense.endDate;
      _dayOfWeek = expense.dayOfWeek ?? DateTime.now().weekday;
      _dayOfMonth = expense.dayOfMonth ?? DateTime.now().day;
      _currencyCode = expense.currencyCode;
      _splitType = expense.splitType;

      if (expense.isGroupExpense) {
        _expenseTarget = _ExpenseTarget.group;
      } else if (expense.isFriendExpense) {
        _expenseTarget = _ExpenseTarget.friend;
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _currencySymbol {
    final symbols = {
      'USD': '\$',
      'EUR': '\u20AC',
      'GBP': '\u00A3',
      'JPY': '\u00A5',
      'INR': '\u20B9',
    };
    return symbols[_currencyCode] ?? '\$';
  }

  Future<void> _selectStartDate() async {
    HapticFeedback.lightImpact();

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentPrimary,
              onPrimary: Colors.black,
              surface: AppTheme.bgCard,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _dayOfMonth = picked.day;
        _dayOfWeek = picked.weekday;
      });
    }
  }

  Future<void> _selectEndDate() async {
    HapticFeedback.lightImpact();

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentPrimary,
              onPrimary: Colors.black,
              surface: AppTheme.bgCard,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _showGroupSelector() {
    HapticFeedback.lightImpact();

    final authService = context.read<AuthService>();
    final userId = authService.userId;
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
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
                'Select Group',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<GroupModel>>(
                  stream: context.read<GroupsService>().streamGroups(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingIndicator(message: 'Loading groups...');
                    }

                    final groups = snapshot.data ?? [];
                    if (groups.isEmpty) {
                      return const EmptyState(
                        icon: Icons.group_add_rounded,
                        title: 'No groups yet',
                        message: 'Create a group to add recurring expenses',
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final isSelected = _selectedGroup?.id == group.id;

                        return AnimatedListItem(
                          index: index,
                          child: PressableScale(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedGroup = group;
                                _currencyCode = group.currencyCode;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.accentPrimary.withOpacity(0.1)
                                    : AppTheme.bgCardLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.accentPrimary
                                      : AppTheme.borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: group.themeColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      group.icon,
                                      color: group.themeColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
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
                                        Text(
                                          '${group.memberCount} members',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppTheme.accentPrimary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFriendSelector() {
    HapticFeedback.lightImpact();

    final authService = context.read<AuthService>();
    final userId = authService.userId;
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
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
                'Select Friend',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<FriendModel>>(
                  stream: context.read<FriendsService>().streamAcceptedFriends(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingIndicator(message: 'Loading friends...');
                    }

                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return const EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No friends yet',
                        message: 'Add friends to create recurring expenses with them',
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isSelected = _selectedFriend?.id == friend.id;

                        return AnimatedListItem(
                          index: index,
                          child: PressableScale(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedFriend = friend;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.accentPrimary.withOpacity(0.1)
                                    : AppTheme.bgCardLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.accentPrimary
                                      : AppTheme.borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  FriendAvatar(
                                    name: friend.displayName,
                                    imageUrl: friend.friendPhotoUrl,
                                    size: 44,
                                    showGradientRing: false,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.displayName,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          friend.friendEmail,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppTheme.accentPrimary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate target selection
    if (_expenseTarget == _ExpenseTarget.group && _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a group'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_expenseTarget == _ExpenseTarget.friend && _selectedFriend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a friend'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final recurringService = context.read<RecurringExpenseService>();

      final userId = authService.userId!;
      final userEmail = authService.currentUser?.email ?? '';
      final userName = authService.currentUser?.displayName;

      final amount = double.parse(_amountController.text);

      // Build participants list
      List<RecurringParticipant> participants = [];

      if (_expenseTarget == _ExpenseTarget.group && _selectedGroup != null) {
        // Get group members and create participants
        // For now, create a simple equal split
        final memberCount = _selectedGroup!.memberCount;
        final splitAmount = amount / memberCount;

        // Add current user as participant/payer
        participants.add(RecurringParticipant(
          memberId: userId,
          userId: userId,
          name: userName,
          email: userEmail,
          amount: splitAmount,
        ));

        // In a real implementation, you'd fetch all group members here
        // For now, we'll just add the current user
      } else if (_expenseTarget == _ExpenseTarget.friend && _selectedFriend != null) {
        // Equal split between user and friend
        final splitAmount = amount / 2;

        participants.add(RecurringParticipant(
          memberId: userId,
          userId: userId,
          name: userName,
          email: userEmail,
          amount: splitAmount,
        ));

        participants.add(RecurringParticipant(
          memberId: _selectedFriend!.friendUserId,
          userId: _selectedFriend!.friendUserId,
          name: _selectedFriend!.friendName,
          email: _selectedFriend!.friendEmail,
          amount: splitAmount,
        ));
      }

      if (_isEditing) {
        // Update existing
        final success = await recurringService.updateRecurringExpense(
          id: widget.existingExpense!.id,
          groupId: widget.existingExpense!.groupId,
          userId: userId,
          description: _descriptionController.text.trim(),
          amount: amount,
          currencyCode: _currencyCode,
          frequency: _frequency,
          startDate: _startDate,
          endDate: _endDate,
          dayOfWeek: _frequency == RecurringFrequency.weekly ||
                  _frequency == RecurringFrequency.biweekly
              ? _dayOfWeek
              : null,
          dayOfMonth: _frequency == RecurringFrequency.monthly ? _dayOfMonth : null,
          splitType: _splitType,
          participants: participants,
          category: _selectedCategory,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );

        if (success && mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // Create new
        final expense = await recurringService.createRecurringExpense(
          groupId: _expenseTarget == _ExpenseTarget.group ? _selectedGroup?.id : null,
          friendId: _expenseTarget == _ExpenseTarget.friend
              ? _selectedFriend?.friendUserId
              : null,
          description: _descriptionController.text.trim(),
          amount: amount,
          currencyCode: _currencyCode,
          frequency: _frequency,
          startDate: _startDate,
          endDate: _endDate,
          dayOfWeek: _frequency == RecurringFrequency.weekly ||
                  _frequency == RecurringFrequency.biweekly
              ? _dayOfWeek
              : null,
          dayOfMonth: _frequency == RecurringFrequency.monthly ? _dayOfMonth : null,
          payerId: userId,
          payerUserId: userId,
          payerName: userName,
          payerEmail: userEmail,
          splitType: _splitType,
          participants: participants,
          category: _selectedCategory,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          createdBy: userId,
        );

        if (expense != null && mounted) {
          HapticFeedback.heavyImpact();
          Navigator.pop(context, expense);
        } else if (recurringService.error != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(recurringService.error!),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        title: Text(
          _isEditing ? 'Edit Recurring Expense' : 'New Recurring Expense',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentPrimary,
                    ),
                  )
                : Text(
                    'Save',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentPrimary,
                    ),
                  ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Target type selector (Group or Friend)
                _buildSectionLabel('Expense Type'),
                const SizedBox(height: 8),
                _buildTargetTypeSelector(),

                const SizedBox(height: 24),

                // Target selector (Group or Friend)
                _buildSectionLabel(_expenseTarget == _ExpenseTarget.group ? 'Group' : 'Friend'),
                const SizedBox(height: 8),
                _buildTargetSelector(),

                const SizedBox(height: 24),

                // Amount input
                _buildSectionLabel('Amount'),
                const SizedBox(height: 8),
                _buildAmountInput(),

                const SizedBox(height: 24),

                // Description
                _buildSectionLabel('Description'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g., Monthly rent, Netflix subscription',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Frequency
                _buildSectionLabel('Frequency'),
                const SizedBox(height: 8),
                _buildFrequencySelector(),

                // Day selector based on frequency
                if (_frequency == RecurringFrequency.weekly ||
                    _frequency == RecurringFrequency.biweekly) ...[
                  const SizedBox(height: 16),
                  _buildDayOfWeekSelector(),
                ],

                if (_frequency == RecurringFrequency.monthly) ...[
                  const SizedBox(height: 16),
                  _buildDayOfMonthSelector(),
                ],

                const SizedBox(height: 24),

                // Start date
                _buildSectionLabel('Start Date'),
                const SizedBox(height: 8),
                _buildDatePicker(
                  date: _startDate,
                  onTap: _selectStartDate,
                  icon: Icons.play_arrow_rounded,
                  color: AppTheme.accentPrimary,
                ),

                const SizedBox(height: 24),

                // End date (optional)
                Row(
                  children: [
                    _buildSectionLabel('End Date'),
                    const SizedBox(width: 8),
                    Text(
                      '(optional)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDatePicker(
                  date: _endDate,
                  onTap: _selectEndDate,
                  icon: Icons.stop_rounded,
                  color: AppTheme.errorColor,
                  placeholder: 'No end date (runs forever)',
                  onClear: _endDate != null
                      ? () => setState(() => _endDate = null)
                      : null,
                ),

                const SizedBox(height: 24),

                // Category
                _buildSectionLabel('Category'),
                const SizedBox(height: 8),
                _buildCategoryChips(),

                const SizedBox(height: 24),

                // Notes (optional)
                _buildSectionLabel('Notes (optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Add any notes...',
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildTargetTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _expenseTarget = _ExpenseTarget.group;
                  _selectedFriend = null;
                });
              },
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _expenseTarget == _ExpenseTarget.group
                      ? AppTheme.accentPrimary.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_rounded,
                      size: 20,
                      color: _expenseTarget == _ExpenseTarget.group
                          ? AppTheme.accentPrimary
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Group',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _expenseTarget == _ExpenseTarget.group
                            ? AppTheme.accentPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _expenseTarget = _ExpenseTarget.friend;
                  _selectedGroup = null;
                });
              },
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _expenseTarget == _ExpenseTarget.friend
                      ? AppTheme.accentPurple.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: _expenseTarget == _ExpenseTarget.friend
                          ? AppTheme.accentPurple
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Friend',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _expenseTarget == _ExpenseTarget.friend
                            ? AppTheme.accentPurple
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelector() {
    if (_expenseTarget == _ExpenseTarget.group) {
      return PressableScale(
        onTap: _showGroupSelector,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              if (_selectedGroup != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _selectedGroup!.themeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _selectedGroup!.icon,
                    color: _selectedGroup!.themeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedGroup!.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${_selectedGroup!.memberCount} members',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: const Icon(
                    Icons.group_add_rounded,
                    color: AppTheme.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Select a group',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      );
    } else {
      return PressableScale(
        onTap: _showFriendSelector,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              if (_selectedFriend != null) ...[
                FriendAvatar(
                  name: _selectedFriend!.displayName,
                  imageUrl: _selectedFriend!.friendPhotoUrl,
                  size: 44,
                  showGradientRing: false,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFriend!.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _selectedFriend!.friendEmail,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: AppTheme.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Select a friend',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAmountInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currencyCode,
              dropdownColor: AppTheme.bgCard,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('\$ USD')),
                DropdownMenuItem(value: 'EUR', child: Text('\u20AC EUR')),
                DropdownMenuItem(value: 'GBP', child: Text('\u00A3 GBP')),
                DropdownMenuItem(value: 'INR', child: Text('\u20B9 INR')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _currencyCode = value);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              prefixText: _currencySymbol,
              prefixStyle: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
              ),
              hintText: '0.00',
              hintStyle: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDim,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter amount';
              }
              if (double.tryParse(value) == null) {
                return 'Invalid number';
              }
              if (double.parse(value) <= 0) {
                return 'Must be > 0';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RecurringFrequency.values.map((freq) {
        final isSelected = _frequency == freq;
        final color = AppTheme.accentPrimary;

        String label;
        IconData icon;
        switch (freq) {
          case RecurringFrequency.daily:
            label = 'Daily';
            icon = Icons.today_rounded;
            break;
          case RecurringFrequency.weekly:
            label = 'Weekly';
            icon = Icons.view_week_rounded;
            break;
          case RecurringFrequency.biweekly:
            label = 'Biweekly';
            icon = Icons.date_range_rounded;
            break;
          case RecurringFrequency.monthly:
            label = 'Monthly';
            icon = Icons.calendar_month_rounded;
            break;
          case RecurringFrequency.yearly:
            label = 'Yearly';
            icon = Icons.event_rounded;
            break;
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _frequency = freq);
          },
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : AppTheme.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? color : AppTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayOfWeekSelector() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repeat on',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final dayNum = index + 1;
            final isSelected = _dayOfWeek == dayNum;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _dayOfWeek = dayNum);
              },
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentPrimary
                      : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentPrimary
                        : AppTheme.borderColor,
                  ),
                ),
                child: Center(
                  child: Text(
                    days[index],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.black
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDayOfMonthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Day of month',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _dayOfMonth.clamp(1, 28),
              isExpanded: true,
              dropdownColor: AppTheme.bgCard,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
              items: List.generate(28, (index) {
                final day = index + 1;
                String suffix;
                if (day >= 11 && day <= 13) {
                  suffix = 'th';
                } else {
                  switch (day % 10) {
                    case 1:
                      suffix = 'st';
                      break;
                    case 2:
                      suffix = 'nd';
                      break;
                    case 3:
                      suffix = 'rd';
                      break;
                    default:
                      suffix = 'th';
                  }
                }
                return DropdownMenuItem(
                  value: day,
                  child: Text('$day$suffix of every month'),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _dayOfMonth = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    DateTime? date,
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    String? placeholder,
    VoidCallback? onClear,
  }) {
    return PressableScale(
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                date != null ? _formatDate(date) : (placeholder ?? 'Select date'),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: date != null ? FontWeight.w500 : FontWeight.w400,
                  color: date != null ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onClear();
                },
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.all.map((category) {
        final isSelected = _selectedCategory == category;
        final color = AppTheme.getCategoryColor(category);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategory = category);
          },
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : AppTheme.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ExpenseCategory.getIcon(category),
                  size: 16,
                  color: isSelected ? color : AppTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  ExpenseCategory.getLabel(category),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? color : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Target type for recurring expense
enum _ExpenseTarget { group, friend }
