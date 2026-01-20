import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';
import '../../models/friend_model.dart';
import '../../services/auth_service.dart';
import '../../services/friends_service.dart';
import '../../widgets/widgets.dart';

/// Screen to settle up with a friend (record a direct payment)
class DirectSettleUpScreen extends StatefulWidget {
  final FriendModel friend;
  final double balance;

  const DirectSettleUpScreen({
    super.key,
    required this.friend,
    required this.balance,
  });

  @override
  State<DirectSettleUpScreen> createState() => _DirectSettleUpScreenState();
}

class _DirectSettleUpScreenState extends State<DirectSettleUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  bool _isLoading = false;
  bool _youArePaying = true; // Based on balance direction
  File? _proofImage;
  bool _showConfetti = false;

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Determine payment direction based on balance
    // If balance > 0, friend owes you, so they should pay
    // If balance < 0, you owe friend, so you should pay
    _youArePaying = widget.balance < 0;

    // Set default amount to full balance
    _amountController.text = widget.balance.abs().toStringAsFixed(2);

    _animController = AnimationController(
      vsync: this,
      duration: AppAnimations.standard,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: AppAnimations.enterCurve,
    );

    _slideAnimation = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: AppAnimations.enterCurve),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
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
              'Add Proof of Payment',
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
        _proofImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSettleUp() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final friendsService = context.read<FriendsService>();

      final currentUserId = authService.userId!;
      final currentUserEmail = authService.currentUser?.email ?? '';
      final currentUserName = authService.currentUser?.displayName;

      final amount = double.parse(_amountController.text);

      // Determine who is paying whom
      String fromUserId;
      String fromUserEmail;
      String? fromUserName;
      String toUserId;
      String toUserEmail;
      String? toUserName;

      if (_youArePaying) {
        fromUserId = currentUserId;
        fromUserEmail = currentUserEmail;
        fromUserName = currentUserName;
        toUserId = widget.friend.friendUserId;
        toUserEmail = widget.friend.friendEmail;
        toUserName = widget.friend.friendName;
      } else {
        fromUserId = widget.friend.friendUserId;
        fromUserEmail = widget.friend.friendEmail;
        fromUserName = widget.friend.friendName;
        toUserId = currentUserId;
        toUserEmail = currentUserEmail;
        toUserName = currentUserName;
      }

      final settlement = await friendsService.createDirectSettlement(
        fromUserId: fromUserId,
        fromUserEmail: fromUserEmail,
        fromUserName: fromUserName,
        toUserId: toUserId,
        toUserEmail: toUserEmail,
        toUserName: toUserName,
        amount: amount,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdBy: currentUserId,
      );

      if (settlement != null && mounted) {
        // Show success animation
        setState(() => _showConfetti = true);
        HapticFeedback.heavyImpact();

        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pop(context, settlement);
        }
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
            content: Text('Failed to record payment: $e'),
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
          'Settle Up',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Balance summary card
                          _buildBalanceSummaryCard(),

                          const SizedBox(height: 32),

                          // Payment direction
                          _buildPaymentDirection(),

                          const SizedBox(height: 24),

                          // Amount input
                          _buildSectionLabel('Amount'),
                          const SizedBox(height: 8),
                          _buildAmountInput(),

                          const SizedBox(height: 24),

                          // Quick amount options
                          _buildQuickAmountOptions(),

                          const SizedBox(height: 24),

                          // Notes
                          _buildSectionLabel('Notes (optional)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 2,
                            style: GoogleFonts.inter(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'e.g., Venmo, Cash, etc.',
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Proof photo
                          _buildSectionLabel('Proof of Payment (optional)'),
                          const SizedBox(height: 8),
                          _buildProofSection(),

                          const SizedBox(height: 40),

                          // Confirm button
                          _buildConfirmButton(),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Confetti overlay
          if (_showConfetti)
            Positioned.fill(
              child: ConfettiAnimation(
                isPlaying: _showConfetti,
                numberOfParticles: 100,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummaryCard() {
    final balanceColor = AppTheme.getBalanceColor(widget.balance);
    final isPositive = widget.balance > 0;

    return GlassCard(
      glowColor: balanceColor,
      child: Column(
        children: [
          // Friend avatar and name
          Row(
            children: [
              FriendAvatar(
                name: widget.friend.displayName,
                imageUrl: widget.friend.friendPhotoUrl,
                size: 50,
                showGradientRing: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.friend.displayName,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      isPositive
                          ? 'owes you'
                          : 'you owe',
                      style: GoogleFonts.inter(
                        fontSize: 13,
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
                    '\$${widget.balance.abs().toStringAsFixed(2)}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: balanceColor,
                    ),
                  ),
                  Text(
                    'current balance',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDirection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Payer
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _youArePaying
                            ? AppTheme.accentPrimary.withOpacity(0.15)
                            : AppTheme.bgCardLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _youArePaying
                              ? AppTheme.accentPrimary
                              : AppTheme.borderColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: _youArePaying
                            ? AppTheme.accentPrimary
                            : AppTheme.textMuted,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _youArePaying ? 'You' : widget.friend.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _youArePaying
                            ? AppTheme.accentPrimary
                            : AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'pays',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.accentPrimary,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _youArePaying = !_youArePaying;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Text(
                          'Swap',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Receiver
              Expanded(
                child: Column(
                  children: [
                    FriendAvatar(
                      name: _youArePaying
                          ? widget.friend.displayName
                          : 'You',
                      imageUrl: _youArePaying
                          ? widget.friend.friendPhotoUrl
                          : null,
                      size: 52,
                      showGradientRing: false,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _youArePaying ? widget.friend.displayName : 'You',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'receives',
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
        ],
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

  Widget _buildAmountInput() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        prefixText: '\$',
        prefixStyle: GoogleFonts.spaceGrotesk(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
        ),
        hintText: '0.00',
        hintStyle: GoogleFonts.spaceGrotesk(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: AppTheme.textDim,
        ),
        filled: true,
        fillColor: AppTheme.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppTheme.accentPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
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
    );
  }

  Widget _buildQuickAmountOptions() {
    final fullBalance = widget.balance.abs();
    final halfBalance = fullBalance / 2;
    final quarterBalance = fullBalance / 4;

    return Row(
      children: [
        _buildQuickAmountChip(quarterBalance, '25%'),
        const SizedBox(width: 8),
        _buildQuickAmountChip(halfBalance, '50%'),
        const SizedBox(width: 8),
        _buildQuickAmountChip(fullBalance, 'Full'),
      ],
    );
  }

  Widget _buildQuickAmountChip(double amount, String label) {
    final isSelected = _amountController.text == amount.toStringAsFixed(2);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _amountController.text = amount.toStringAsFixed(2);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentPrimary.withOpacity(0.15)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentPrimary
                  : AppTheme.borderColor,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppTheme.accentPrimary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppTheme.accentPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProofSection() {
    if (_proofImage != null) {
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
                _proofImage!,
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
                    onPressed: _pickProofImage,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Replace'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _proofImage = null);
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
      onTap: _pickProofImage,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
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
                Icons.camera_alt_rounded,
                color: AppTheme.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add proof of payment',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
            Text(
              'Screenshot, receipt, etc.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final amount = double.tryParse(_amountController.text) ?? 0;

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentPrimary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSettleUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Confirm \$${amount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
