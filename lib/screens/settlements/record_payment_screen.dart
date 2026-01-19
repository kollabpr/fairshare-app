import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/group_model.dart';
import '../../models/group_member_model.dart';
import '../../services/groups_service.dart';
import '../../services/expenses_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';

/// Screen for recording a payment between group members
class RecordPaymentScreen extends StatefulWidget {
  final GroupModel group;
  final GroupMemberModel? preselectedFrom;
  final GroupMemberModel? preselectedTo;
  final double? preselectedAmount;

  const RecordPaymentScreen({
    super.key,
    required this.group,
    this.preselectedFrom,
    this.preselectedTo,
    this.preselectedAmount,
  });

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  List<GroupMemberModel> _members = [];
  GroupMemberModel? _fromMember;
  GroupMemberModel? _toMember;
  DateTime _date = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    if (widget.preselectedAmount != null) {
      _amountController.text = widget.preselectedAmount!.toStringAsFixed(2);
    }
  }

  Future<void> _loadMembers() async {
    final members = await context.read<GroupsService>().getMembers(widget.group.id);
    setState(() {
      _members = members;
      _fromMember = widget.preselectedFrom ??
          members.firstWhere(
            (m) => m.userId == context.read<AuthService>().userId,
            orElse: () => members.first,
          );
      _toMember = widget.preselectedTo;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Record Payment'),
        backgroundColor: AppTheme.bgPrimary,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Amount input
              Text(
                'Amount',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: widget.group.currencySymbol,
                  prefixStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  hintText: '0.00',
                  hintStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                  border: InputBorder.none,
                  filled: false,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount > 100000) {
                    return 'Amount cannot exceed ${widget.group.currencySymbol}100,000';
                  }
                  return null;
                },
              ),
              const Divider(),
              const SizedBox(height: 24),

              // From member
              Text(
                'From (Payer)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildMemberDropdown(
                value: _fromMember,
                onChanged: (member) {
                  setState(() => _fromMember = member);
                },
                excludeId: _toMember?.id,
              ),
              const SizedBox(height: 20),

              // To member
              Text(
                'To (Recipient)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildMemberDropdown(
                value: _toMember,
                onChanged: (member) {
                  setState(() => _toMember = member);
                },
                excludeId: _fromMember?.id,
                hint: 'Select recipient',
              ),
              const SizedBox(height: 20),

              // Date
              Text(
                'Date',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDate(_date),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Notes (optional)
              Text(
                'Notes (Optional)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Venmo, cash, bank transfer...',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _fromMember != null && _toMember != null
                    ? _submitPayment
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Record Payment',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberDropdown({
    required GroupMemberModel? value,
    required ValueChanged<GroupMemberModel?> onChanged,
    String? excludeId,
    String hint = 'Select member',
  }) {
    final availableMembers = _members
        .where((m) => m.id != excludeId)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GroupMemberModel>(
          isExpanded: true,
          value: value,
          hint: Text(
            hint,
            style: GoogleFonts.inter(color: AppTheme.textMuted),
          ),
          dropdownColor: AppTheme.bgCard,
          items: availableMembers.map((member) {
            return DropdownMenuItem(
              value: member,
              child: Row(
                children: [
                  MemberAvatar(member: member, radius: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          member.nickname,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (member.isGhostUser)
                          Text(
                            'Not signed up',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentPrimary,
              surface: AppTheme.bgCard,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';

    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromMember == null || _toMember == null) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final userId = context.read<AuthService>().userId!;

      await context.read<ExpensesService>().createSettlement(
        groupId: widget.group.id,
        fromMemberId: _fromMember!.id,
        toMemberId: _toMember!.id,
        fromUserId: _fromMember!.userId,
        toUserId: _toMember!.userId,
        amount: amount,
        currencyCode: widget.group.currencyCode,
        date: _date,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdBy: userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
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
}
