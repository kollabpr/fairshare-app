import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';
import '../../models/friend_model.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/auth_service.dart';
import '../../services/friends_service.dart';
import '../../widgets/widgets.dart';

/// Screen to add a direct expense between two friends (Splitwise-like)
class AddDirectExpenseScreen extends StatefulWidget {
  /// Pre-selected friend (optional - can be selected in screen)
  final FriendModel? friend;

  const AddDirectExpenseScreen({
    super.key,
    this.friend,
  });

  @override
  State<AddDirectExpenseScreen> createState() => _AddDirectExpenseScreenState();
}

class _AddDirectExpenseScreenState extends State<AddDirectExpenseScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _customYouOweController = TextEditingController();
  final _customTheyOweController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  FriendModel? _selectedFriend;
  String _selectedCategory = 'other';
  DateTime _selectedDate = DateTime.now();
  bool _youPaid = true; // true = you paid, false = they paid
  _SplitOption _splitOption = _SplitOption.equal;
  bool _isLoading = false;
  File? _receiptImage;
  String _currencyCode = 'USD';

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedFriend = widget.friend;

    _animController = AnimationController(
      vsync: this,
      duration: AppAnimations.standard,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: AppAnimations.enterCurve,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _customYouOweController.dispose();
    _customTheyOweController.dispose();
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

  Future<void> _pickReceiptImage() async {
    HapticFeedback.lightImpact();

    final source = await showModalBottomSheet<ImageSource>(
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
            Text(
              'Add Receipt Photo',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt_rounded, color: AppTheme.accentPrimary),
              ),
              title: Text('Take Photo', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_library_rounded, color: AppTheme.accentBlue),
              ),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 1024,
    );

    if (pickedFile != null) {
      setState(() {
        _receiptImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate() async {
    HapticFeedback.lightImpact();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
        _selectedDate = picked;
      });
    }
  }

  void _showFriendSelector() {
    HapticFeedback.lightImpact();

    final authService = context.read<AuthService>();
    final userId = authService.userId;
    if (userId == null) return;

    final friendsService = context.read<FriendsService>();

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
                  stream: friendsService.streamAcceptedFriends(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingIndicator(message: 'Loading friends...');
                    }

                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return const EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No friends yet',
                        message: 'Add friends to start splitting expenses',
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

    if (_selectedFriend == null) {
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
      final friendsService = context.read<FriendsService>();

      final currentUserId = authService.userId!;
      final currentUserEmail = authService.currentUser?.email ?? '';
      final currentUserName = authService.currentUser?.displayName;

      final amount = double.parse(_amountController.text);

      // Determine payer and participant based on who paid
      String payerId;
      String payerEmail;
      String? payerName;
      String participantId;
      String participantEmail;
      String? participantName;

      if (_youPaid) {
        payerId = currentUserId;
        payerEmail = currentUserEmail;
        payerName = currentUserName;
        participantId = _selectedFriend!.friendUserId;
        participantEmail = _selectedFriend!.friendEmail;
        participantName = _selectedFriend!.friendName;
      } else {
        payerId = _selectedFriend!.friendUserId;
        payerEmail = _selectedFriend!.friendEmail;
        payerName = _selectedFriend!.friendName;
        participantId = currentUserId;
        participantEmail = currentUserEmail;
        participantName = currentUserName;
      }

      // Calculate split amounts based on split option
      double? customPayerAmount;
      double? customParticipantAmount;

      switch (_splitOption) {
        case _SplitOption.equal:
          // Default equal split - handled by service
          break;
        case _SplitOption.youOweFull:
          // You owe the full amount to them
          if (_youPaid) {
            // You paid but owe full - doesn't make sense, participant owes 0
            customPayerAmount = amount;
            customParticipantAmount = 0;
          } else {
            // They paid, you owe full
            customPayerAmount = 0;
            customParticipantAmount = amount;
          }
          break;
        case _SplitOption.theyOweFull:
          // They owe the full amount
          if (_youPaid) {
            // You paid, they owe full
            customPayerAmount = 0;
            customParticipantAmount = amount;
          } else {
            // They paid but owe full - doesn't make sense
            customPayerAmount = amount;
            customParticipantAmount = 0;
          }
          break;
        case _SplitOption.custom:
          // Custom amounts
          final youOwe = double.tryParse(_customYouOweController.text) ?? 0;
          final theyOwe = double.tryParse(_customTheyOweController.text) ?? 0;

          if (_youPaid) {
            customPayerAmount = youOwe;
            customParticipantAmount = theyOwe;
          } else {
            customPayerAmount = theyOwe;
            customParticipantAmount = youOwe;
          }
          break;
      }

      final expense = await friendsService.createDirectExpense(
        description: _descriptionController.text.trim(),
        amount: amount,
        payerId: payerId,
        payerEmail: payerEmail,
        payerName: payerName,
        participantId: participantId,
        participantEmail: participantEmail,
        participantName: participantName,
        currencyCode: _currencyCode,
        date: _selectedDate,
        category: _selectedCategory,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        splitType: _splitOption == _SplitOption.equal
            ? SplitType.equal
            : SplitType.exact,
        customPayerAmount: customPayerAmount,
        customParticipantAmount: customParticipantAmount,
        createdBy: currentUserId,
      );

      if (expense != null && mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, expense);
      } else if (friendsService.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendsService.error!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create expense: $e'),
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
          'Add Expense',
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
                // Friend selector
                _buildSectionLabel('With'),
                const SizedBox(height: 8),
                _buildFriendSelector(),

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
                    hintText: 'What was this for?',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Who paid toggle
                _buildSectionLabel('Paid by'),
                const SizedBox(height: 8),
                _buildWhoPaidToggle(),

                const SizedBox(height: 24),

                // Split type
                _buildSectionLabel('Split'),
                const SizedBox(height: 8),
                _buildSplitOptions(),

                // Custom split inputs
                if (_splitOption == _SplitOption.custom) ...[
                  const SizedBox(height: 16),
                  _buildCustomSplitInputs(),
                ],

                const SizedBox(height: 24),

                // Category
                _buildSectionLabel('Category'),
                const SizedBox(height: 8),
                _buildCategoryChips(),

                const SizedBox(height: 24),

                // Date picker
                _buildSectionLabel('Date'),
                const SizedBox(height: 8),
                _buildDatePicker(),

                const SizedBox(height: 24),

                // Optional: Notes
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

                const SizedBox(height: 24),

                // Receipt photo
                _buildSectionLabel('Receipt (optional)'),
                const SizedBox(height: 8),
                _buildReceiptSection(),

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

  Widget _buildFriendSelector() {
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
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Icon(
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
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Currency selector
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
        // Amount input
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
            onChanged: (value) {
              // Update custom split defaults when amount changes
              if (_splitOption == _SplitOption.custom) {
                final amount = double.tryParse(value) ?? 0;
                final half = (amount / 2).toStringAsFixed(2);
                _customYouOweController.text = half;
                _customTheyOweController.text = half;
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWhoPaidToggle() {
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
                setState(() => _youPaid = true);
              },
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _youPaid
                      ? AppTheme.accentPrimary.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: _youPaid
                          ? AppTheme.accentPrimary
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'You paid',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _youPaid
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
                setState(() => _youPaid = false);
              },
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !_youPaid
                      ? AppTheme.accentPurple.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: !_youPaid
                          ? AppTheme.accentPurple
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedFriend?.displayName ?? 'They',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: !_youPaid
                            ? AppTheme.accentPurple
                            : AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ' paid',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: !_youPaid
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

  Widget _buildSplitOptions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSplitChip(
          _SplitOption.equal,
          'Equal',
          Icons.balance_rounded,
          AppTheme.accentPrimary,
        ),
        _buildSplitChip(
          _SplitOption.youOweFull,
          'You owe full',
          Icons.arrow_forward_rounded,
          AppTheme.owesColor,
        ),
        _buildSplitChip(
          _SplitOption.theyOweFull,
          'They owe full',
          Icons.arrow_back_rounded,
          AppTheme.getBackColor,
        ),
        _buildSplitChip(
          _SplitOption.custom,
          'Custom',
          Icons.tune_rounded,
          AppTheme.accentPurple,
        ),
      ],
    );
  }

  Widget _buildSplitChip(
    _SplitOption option,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _splitOption == option;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _splitOption = option;
          if (option == _SplitOption.custom) {
            final amount = double.tryParse(_amountController.text) ?? 0;
            final half = (amount / 2).toStringAsFixed(2);
            _customYouOweController.text = half;
            _customTheyOweController.text = half;
          }
        });
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
  }

  Widget _buildCustomSplitInputs() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You owe',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _customYouOweController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  prefixText: _currencySymbol,
                  prefixStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_selectedFriend?.displayName ?? 'They'} owe${_selectedFriend == null ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _customTheyOweController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  prefixText: _currencySymbol,
                  prefixStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

  Widget _buildDatePicker() {
    return PressableScale(
      onTap: _selectDate,
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
                color: AppTheme.accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.accentBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _formatDate(_selectedDate),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
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
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildReceiptSection() {
    if (_receiptImage != null) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                _receiptImage!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _pickReceiptImage,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Replace'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _receiptImage = null);
                    },
                    icon: Icon(Icons.delete_rounded, color: AppTheme.errorColor),
                    label: Text(
                      'Remove',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return PressableScale(
      onTap: _pickReceiptImage,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.borderColor,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.add_a_photo_rounded,
                color: AppTheme.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add receipt photo',
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

/// Split options for direct expense
enum _SplitOption {
  equal,
  youOweFull,
  theyOweFull,
  custom,
}
