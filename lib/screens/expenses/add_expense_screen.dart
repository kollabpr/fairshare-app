import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/group_member_model.dart';
import '../../services/auth_service.dart';
import '../../services/groups_service.dart';
import '../../services/expenses_service.dart';
import '../../services/splitting_service.dart';
import '../../services/ocr_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final GroupModel group;

  const AddExpenseScreen({super.key, required this.group});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'other';
  SplitType _splitType = SplitType.equal;
  DateTime _selectedDate = DateTime.now();
  String? _selectedPayerId;
  List<GroupMemberModel> _members = [];
  Set<String> _selectedParticipants = {};
  bool _isLoading = false;
  bool _isScanning = false;
  File? _receiptImage;

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _splitType = widget.group.defaultSplitType;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members = await context.read<GroupsService>().getMembers(widget.group.id);
    setState(() {
      _members = members;
      // Default: current user is payer, all members participate
      final userId = context.read<AuthService>().userId;
      _selectedPayerId = members.firstWhere(
        (m) => m.userId == userId,
        orElse: () => members.first,
      ).id;
      _selectedParticipants = members.map((m) => m.id).toSet();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
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
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.accentPrimary),
              title: Text('Take Photo', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.accentPrimary),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 60, // Compress to save storage
      maxWidth: 1024,
    );

    if (pickedFile == null) return;

    setState(() {
      _isScanning = true;
      _receiptImage = File(pickedFile.path);
    });

    try {
      final ocrService = context.read<OCRService>();
      final receiptData = await ocrService.scanReceipt(File(pickedFile.path));

      // Auto-fill form
      if (receiptData.amount != null) {
        _amountController.text = receiptData.amount!.toStringAsFixed(2);
      }
      if (receiptData.merchant != null && _descriptionController.text.isEmpty) {
        _descriptionController.text = receiptData.merchant!;
      }
      if (receiptData.date != null) {
        _selectedDate = receiptData.date!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt scanned successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to scan receipt: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPayerId == null) return;
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one participant'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final participants = _members
          .where((m) => _selectedParticipants.contains(m.id))
          .toList();

      // Calculate splits
      final splittingService = context.read<SplittingService>();
      final splits = splittingService.calculateSplits(
        expenseId: '',
        amount: amount,
        payerId: _selectedPayerId!,
        participants: participants,
        splitType: _splitType,
      );

      // Create expense
      final expensesService = context.read<ExpensesService>();
      final expense = await expensesService.createExpense(
        groupId: widget.group.id,
        description: _descriptionController.text.trim(),
        amount: amount,
        payerId: _selectedPayerId!,
        payerUserId: _members.firstWhere((m) => m.id == _selectedPayerId).userId,
        createdBy: context.read<AuthService>().userId!,
        splits: splits,
        currencyCode: widget.group.currencyCode,
        date: _selectedDate,
        category: _selectedCategory,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        splitType: _splitType,
      );

      if (expense != null && mounted) {
        Navigator.pop(context);
      } else if (expensesService.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(expensesService.error!),
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: Text(
          'Add Expense',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scan receipt button
              Center(
                child: OutlinedButton.icon(
                  onPressed: _isScanning ? null : _scanReceipt,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan Receipt'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),

              if (_receiptImage != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _receiptImage!,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Amount
              Text(
                'Amount',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: widget.group.currencySymbol,
                  prefixStyle: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                  hintText: '0.00',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Description
              Text(
                'Description',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
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

              const SizedBox(height: 20),

              // Paid by
              Text(
                'Paid by',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPayerId,
                dropdownColor: AppTheme.bgCard,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
                ),
                items: _members.map((member) {
                  return DropdownMenuItem(
                    value: member.id,
                    child: Text(
                      member.nickname,
                      style: GoogleFonts.inter(color: AppTheme.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedPayerId = value),
              ),

              const SizedBox(height: 20),

              // Split type
              Text(
                'Split Type',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<SplitType>(
                segments: const [
                  ButtonSegment(
                    value: SplitType.equal,
                    label: Text('Equal'),
                    icon: Icon(Icons.balance, size: 18),
                  ),
                  ButtonSegment(
                    value: SplitType.equity,
                    label: Text('Fair'),
                    icon: Icon(Icons.auto_awesome, size: 18),
                  ),
                ],
                selected: {_splitType},
                onSelectionChanged: (selected) {
                  setState(() => _splitType = selected.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.accentPrimary.withOpacity(0.15);
                    }
                    return AppTheme.bgCard;
                  }),
                ),
              ),

              const SizedBox(height: 20),

              // Category
              Text(
                'Category',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.all.map((category) {
                  final isSelected = _selectedCategory == category;
                  return FilterChip(
                    selected: isSelected,
                    label: Text(ExpenseCategory.getLabel(category)),
                    avatar: Icon(
                      ExpenseCategory.getIcon(category),
                      size: 18,
                      color: isSelected
                          ? AppTheme.accentPrimary
                          : AppTheme.textMuted,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = category),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Participants
              Text(
                'Split between',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _members.map((member) {
                  final isSelected = _selectedParticipants.contains(member.id);
                  return FilterChip(
                    selected: isSelected,
                    label: Text(member.nickname),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedParticipants.add(member.id);
                        } else {
                          _selectedParticipants.remove(member.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
