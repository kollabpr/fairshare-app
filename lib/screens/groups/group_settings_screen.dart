import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/group_model.dart';
import '../../services/groups_service.dart';
import '../../widgets/widgets.dart';
import 'members_screen.dart';

/// Screen for editing group settings
class GroupSettingsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupSettingsScreen({super.key, required this.group});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late GroupModel _group;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.bgPrimary,
        appBar: AppBar(
          title: const Text('Group Settings'),
          backgroundColor: AppTheme.bgPrimary,
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _saveChanges,
                child: Text(
                  'Save',
                  style: GoogleFonts.inter(
                    color: AppTheme.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        body: LoadingOverlay(
          isLoading: _isLoading,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Group icon and name
              _buildGroupHeader(),
              const SizedBox(height: 24),

              // Settings sections
              _buildSection(
                title: 'General',
                children: [
                  _buildNameTile(),
                  _buildDescriptionTile(),
                  _buildCurrencyTile(),
                ],
              ),
              const SizedBox(height: 24),

              _buildSection(
                title: 'Split Settings',
                children: [
                  _buildDefaultSplitTypeTile(),
                  _buildSimplifyDebtsTile(),
                ],
              ),
              const SizedBox(height: 24),

              _buildSection(
                title: 'Members',
                children: [
                  _buildMembersTile(),
                ],
              ),
              const SizedBox(height: 24),

              _buildSection(
                title: 'Customization',
                children: [
                  _buildIconTile(),
                  _buildColorTile(),
                ],
              ),
              const SizedBox(height: 24),

              // Danger zone
              _buildSection(
                title: 'Danger Zone',
                titleColor: AppTheme.errorColor,
                children: [
                  _buildArchiveTile(),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader() {
    return GlassCard(
      glowColor: _group.themeColor,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _group.themeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _group.icon,
              color: _group.themeColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _group.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_group.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    _group.description!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    Color? titleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: titleColor ?? AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildNameTile() {
    return ListTile(
      leading: const Icon(Icons.edit_outlined),
      title: const Text('Group Name'),
      subtitle: Text(_group.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: _editName,
    );
  }

  Widget _buildDescriptionTile() {
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: const Text('Description'),
      subtitle: Text(_group.description ?? 'No description'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _editDescription,
    );
  }

  Widget _buildCurrencyTile() {
    return ListTile(
      leading: const Icon(Icons.attach_money_rounded),
      title: const Text('Currency'),
      subtitle: Text('${_group.currencySymbol} (${_group.currencyCode})'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _selectCurrency,
    );
  }

  Widget _buildDefaultSplitTypeTile() {
    return ListTile(
      leading: const Icon(Icons.pie_chart_outline_rounded),
      title: const Text('Default Split Type'),
      subtitle: Text(_group.defaultSplitType.name.toUpperCase()),
      trailing: const Icon(Icons.chevron_right),
      onTap: _selectSplitType,
    );
  }

  Widget _buildSimplifyDebtsTile() {
    return SwitchListTile(
      secondary: const Icon(Icons.auto_awesome_outlined),
      title: const Text('Simplify Debts'),
      subtitle: const Text('Minimize payment transactions'),
      value: _group.simplifyDebts,
      onChanged: (value) {
        setState(() {
          _group = _group.copyWith(simplifyDebts: value);
          _hasChanges = true;
        });
      },
    );
  }

  Widget _buildMembersTile() {
    return ListTile(
      leading: const Icon(Icons.people_outline_rounded),
      title: const Text('Manage Members'),
      subtitle: Text('${_group.memberCount} member${_group.memberCount != 1 ? 's' : ''}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MembersScreen(group: _group),
          ),
        );
      },
    );
  }

  Widget _buildIconTile() {
    return ListTile(
      leading: Icon(_group.icon, color: _group.themeColor),
      title: const Text('Group Icon'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _selectIcon,
    );
  }

  Widget _buildColorTile() {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _group.themeColor,
          shape: BoxShape.circle,
        ),
      ),
      title: const Text('Theme Color'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _selectColor,
    );
  }

  Widget _buildArchiveTile() {
    return ListTile(
      leading: Icon(Icons.archive_outlined, color: AppTheme.errorColor),
      title: Text(
        'Archive Group',
        style: TextStyle(color: AppTheme.errorColor),
      ),
      subtitle: const Text('Hide this group from your list'),
      onTap: _confirmArchive,
    );
  }

  void _editName() {
    _showEditDialog(
      title: 'Edit Group Name',
      initialValue: _group.name,
      hint: 'Group name',
      onSave: (value) {
        setState(() {
          _group = _group.copyWith(name: value);
          _hasChanges = true;
        });
      },
    );
  }

  void _editDescription() {
    _showEditDialog(
      title: 'Edit Description',
      initialValue: _group.description ?? '',
      hint: 'Description (optional)',
      maxLines: 3,
      onSave: (value) {
        setState(() {
          _group = _group.copyWith(description: value.isEmpty ? null : value);
          _hasChanges = true;
        });
      },
    );
  }

  void _selectCurrency() {
    final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'INR', 'CAD', 'AUD'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Select Currency',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...currencies.map((currency) => ListTile(
            title: Text(currency),
            trailing: _group.currencyCode == currency
                ? const Icon(Icons.check, color: AppTheme.accentPrimary)
                : null,
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _group = _group.copyWith(currencyCode: currency);
                _hasChanges = true;
              });
            },
          )),
        ],
      ),
    );
  }

  void _selectSplitType() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Default Split Type',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...SplitType.values.map((type) => ListTile(
            title: Text(type.name.toUpperCase()),
            subtitle: Text(_getSplitTypeDescription(type)),
            trailing: _group.defaultSplitType == type
                ? const Icon(Icons.check, color: AppTheme.accentPrimary)
                : null,
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _group = _group.copyWith(defaultSplitType: type);
                _hasChanges = true;
              });
            },
          )),
        ],
      ),
    );
  }

  String _getSplitTypeDescription(SplitType type) {
    switch (type) {
      case SplitType.equal:
        return 'Split evenly among all participants';
      case SplitType.exact:
        return 'Enter specific amounts for each person';
      case SplitType.percentage:
        return 'Split by percentage (must total 100%)';
      case SplitType.shares:
        return 'Split by number of shares';
      case SplitType.equity:
        return 'Split based on income weights';
    }
  }

  void _selectIcon() {
    final icons = {
      'home': Icons.home_rounded,
      'trip': Icons.flight_rounded,
      'food': Icons.restaurant_rounded,
      'party': Icons.celebration_rounded,
      'work': Icons.work_outline_rounded,
      'sport': Icons.sports_basketball_rounded,
      'shopping': Icons.shopping_bag_rounded,
      'other': Icons.group_rounded,
    };

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Icon',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: icons.entries.map((entry) {
                final isSelected = _group.iconName == entry.key;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _group = _group.copyWith(iconName: entry.key);
                      _hasChanges = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentPrimary.withOpacity(0.2)
                          : AppTheme.bgTertiary,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: AppTheme.accentPrimary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      entry.value,
                      color: isSelected
                          ? AppTheme.accentPrimary
                          : AppTheme.textMuted,
                      size: 28,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _selectColor() {
    final colors = [
      '#6366f1', // Indigo
      '#3b82f6', // Blue
      '#10b981', // Emerald
      '#f59e0b', // Amber
      '#ef4444', // Red
      '#ec4899', // Pink
      '#8b5cf6', // Purple
      '#06b6d4', // Cyan
    ];

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Color',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: colors.map((hex) {
                final color = Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
                final isSelected = _group.colorHex == hex;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _group = _group.copyWith(colorHex: hex);
                      _hasChanges = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog({
    required String title,
    required String initialValue,
    required String hint,
    required ValueChanged<String> onSave,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onSave(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmArchive() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Group'),
        content: Text(
          'Are you sure you want to archive "${_group.name}"? '
          'This will hide it from your groups list. '
          'Outstanding balances will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _archiveGroup();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveGroup() async {
    setState(() => _isLoading = true);

    final success = await context.read<GroupsService>().archiveGroup(_group.id);

    if (mounted) {
      if (success) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group archived'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to archive group'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    final success = await context.read<GroupsService>().updateGroup(_group);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
