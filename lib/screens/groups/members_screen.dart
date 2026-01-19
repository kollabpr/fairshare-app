import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/group_model.dart';
import '../../models/group_member_model.dart';
import '../../services/groups_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';

/// Screen for managing group members
class MembersScreen extends StatefulWidget {
  final GroupModel group;

  const MembersScreen({super.key, required this.group});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  bool _isCurrentUserAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final userId = context.read<AuthService>().userId;
    final members = await context.read<GroupsService>().getMembers(widget.group.id);
    final currentMember = members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => GroupMemberModel(
        id: '',
        nickname: '',
        joinedAt: DateTime.now(),
      ),
    );
    setState(() {
      _isCurrentUserAdmin = currentMember.isAdmin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Members'),
        backgroundColor: AppTheme.bgPrimary,
      ),
      body: StreamBuilder<List<GroupMemberModel>>(
        stream: context.read<GroupsService>().streamMembers(widget.group.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading members...');
          }

          final members = snapshot.data ?? [];

          if (members.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No members',
              message: 'Add members to start splitting expenses',
            );
          }

          // Sort: admins first, then by name
          final sortedMembers = List<GroupMemberModel>.from(members)
            ..sort((a, b) {
              if (a.isAdmin && !b.isAdmin) return -1;
              if (!a.isAdmin && b.isAdmin) return 1;
              return a.nickname.compareTo(b.nickname);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedMembers.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildHeader(members.length);
              }

              final member = sortedMembers[index - 1];
              return _MemberTile(
                member: member,
                group: widget.group,
                isCurrentUserAdmin: _isCurrentUserAdmin,
                onEdit: () => _editMember(member),
                onRemove: () => _confirmRemoveMember(member),
              );
            },
          );
        },
      ),
      floatingActionButton: _isCurrentUserAdmin
          ? FloatingActionButton.extended(
              onPressed: _addMember,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Member'),
              backgroundColor: AppTheme.accentPrimary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildHeader(int memberCount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$memberCount member${memberCount != 1 ? 's' : ''}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          if (_isCurrentUserAdmin)
            TextButton.icon(
              onPressed: _generateInviteLink,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Invite Link'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentPrimary,
              ),
            ),
        ],
      ),
    );
  }

  void _addMember() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMemberSheet(
        group: widget.group,
        onMemberAdded: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member added successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        },
      ),
    );
  }

  void _editMember(GroupMemberModel member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditMemberSheet(
        group: widget.group,
        member: member,
        onSaved: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmRemoveMember(GroupMemberModel member) {
    if (member.balance.abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${member.nickname} has an outstanding balance. '
            'Settle up before removing.',
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${member.nickname} from this group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeMember(member);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(GroupMemberModel member) async {
    final success = await context.read<GroupsService>().removeMember(
      widget.group.id,
      member.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${member.nickname} removed from group'
                : 'Failed to remove member',
          ),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  void _generateInviteLink() {
    // Generate a simple invite code for now
    final inviteCode = '${widget.group.id.substring(0, 6).toUpperCase()}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this code with people you want to invite:',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgTertiary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                inviteCode,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentPrimary,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard')),
              );
            },
            child: const Text('Copy Code'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// Member list tile
class _MemberTile extends StatelessWidget {
  final GroupMemberModel member;
  final GroupModel group;
  final bool isCurrentUserAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.member,
    required this.group,
    required this.isCurrentUserAdmin,
    this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().userId;
    final isCurrentUser = member.userId == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            MemberAvatar(member: member, radius: 22),
            if (member.isAdmin)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.bgCard, width: 2),
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                member.nickname,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'You',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.isGhostUser)
              Text(
                'Not signed up yet',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (member.email != null)
              Text(
                member.email!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BalanceBadge(
              balance: member.balance,
              currencySymbol: group.currencySymbol,
            ),
            if (isCurrentUserAdmin && !isCurrentUser) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'remove') onRemove?.call();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove_outlined, size: 20, color: AppTheme.errorColor),
                        const SizedBox(width: 12),
                        Text('Remove', style: TextStyle(color: AppTheme.errorColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for adding a new member
class _AddMemberSheet extends StatefulWidget {
  final GroupModel group;
  final VoidCallback? onMemberAdded;

  const _AddMemberSheet({
    required this.group,
    this.onMemberAdded,
  });

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Member',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add someone to split expenses with. They can join later.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Alex',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                if (value.trim().length > 50) {
                  return 'Name is too long';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (Optional)',
                hintText: 'For sending invites',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addMember,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Member'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userId = context.read<AuthService>().userId;
    final member = await context.read<GroupsService>().addMember(
      groupId: widget.group.id,
      nickname: _nicknameController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      invitedBy: userId,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (member != null) {
        widget.onMemberAdded?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add member'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

/// Bottom sheet for editing a member
class _EditMemberSheet extends StatefulWidget {
  final GroupModel group;
  final GroupMemberModel member;
  final VoidCallback? onSaved;

  const _EditMemberSheet({
    required this.group,
    required this.member,
    this.onSaved,
  });

  @override
  State<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends State<_EditMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final TextEditingController _weightController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.member.nickname);
    _weightController = TextEditingController(
      text: widget.member.salaryWeight.toString(),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Member',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Nickname',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a nickname';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _weightController,
              decoration: InputDecoration(
                labelText: 'Salary Weight',
                helperText: 'Used for equity splitting (default: 1.0)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a weight';
                }
                final weight = double.tryParse(value);
                if (weight == null || weight <= 0) {
                  return 'Please enter a valid weight';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final weight = double.parse(_weightController.text);

    await context.read<GroupsService>().updateMemberWeight(
      widget.group.id,
      widget.member.id,
      weight,
    );

    // TODO: Update nickname through a new method in GroupsService

    if (mounted) {
      setState(() => _isLoading = false);
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member updated'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }
}
