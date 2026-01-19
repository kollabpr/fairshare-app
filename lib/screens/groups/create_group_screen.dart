import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/group_model.dart';
import '../../services/auth_service.dart';
import '../../services/groups_service.dart';
import 'group_detail_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedIcon = 'friends';
  String _selectedCurrency = 'USD';
  SplitType _defaultSplitType = SplitType.equal;
  bool _isLoading = false;

  final _icons = {
    'friends': Icons.group_rounded,
    'home': Icons.home_rounded,
    'trip': Icons.flight_rounded,
    'food': Icons.restaurant_rounded,
    'couple': Icons.favorite_rounded,
    'work': Icons.work_rounded,
    'party': Icons.celebration_rounded,
    'shopping': Icons.shopping_bag_rounded,
  };

  final _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'INR', 'JPY'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthService>();
    final groupsService = context.read<GroupsService>();

    final group = await groupsService.createGroup(
      name: _nameController.text.trim(),
      userId: auth.userId!,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      currencyCode: _selectedCurrency,
      iconName: _selectedIcon,
      defaultSplitType: _defaultSplitType,
    );

    setState(() => _isLoading = false);

    if (group != null && mounted) {
      // Replace current screen with group detail
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
      );
    } else if (groupsService.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groupsService.error!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: Text(
          'Create Group',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group name
              Text(
                'Group Name',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g., Vegas Trip, Apartment 4B',
                  prefixIcon: Icon(Icons.group_outlined, color: AppTheme.textMuted),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Description (optional)
              Text(
                'Description (Optional)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                style: GoogleFonts.inter(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Add a description...',
                ),
              ),

              const SizedBox(height: 24),

              // Icon selection
              Text(
                'Group Icon',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _icons.entries.map((entry) {
                  final isSelected = _selectedIcon == entry.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = entry.key),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentPrimary.withOpacity(0.15)
                            : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentPrimary
                              : AppTheme.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        entry.value,
                        color: isSelected
                            ? AppTheme.accentPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Currency selection
              Text(
                'Currency',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                dropdownColor: AppTheme.bgCard,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.attach_money, color: AppTheme.textMuted),
                ),
                items: _currencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency,
                    child: Text(currency, style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCurrency = value);
                  }
                },
              ),

              const SizedBox(height: 24),

              // Default split type
              Text(
                'Default Split Type',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _buildSplitTypeOption(
                type: SplitType.equal,
                title: 'Equal Split',
                description: 'Everyone pays the same amount',
                icon: Icons.balance_rounded,
              ),
              const SizedBox(height: 8),
              _buildSplitTypeOption(
                type: SplitType.equity,
                title: 'Fair Split (Income-Based)',
                description: 'Higher earners pay more',
                icon: Icons.auto_awesome_rounded,
              ),

              const SizedBox(height: 40),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create Group',
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

  Widget _buildSplitTypeOption({
    required SplitType type,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _defaultSplitType == type;

    return GestureDetector(
      onTap: () => setState(() => _defaultSplitType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentPrimary.withOpacity(0.1)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.accentPrimary : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accentPrimary : AppTheme.textMuted,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppTheme.accentPrimary,
              ),
          ],
        ),
      ),
    );
  }
}
