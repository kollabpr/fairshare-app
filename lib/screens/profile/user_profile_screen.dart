import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';

/// User profile and settings screen
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  String _selectedCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _selectedCurrency = user?.defaultCurrency ?? 'USD';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: AppTheme.bgPrimary,
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _saveProfile,
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
      body: authService.isLoading
          ? const LoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile header
                _buildProfileHeader(user),
                const SizedBox(height: 24),

                // Profile section
                _buildSection(
                  title: 'Profile',
                  children: [
                    _buildNameTile(user),
                    _buildEmailTile(user),
                    _buildCurrencyTile(),
                  ],
                ),
                const SizedBox(height: 24),

                // Preferences section
                _buildSection(
                  title: 'Preferences',
                  children: [
                    _buildNotificationsTile(),
                    _buildThemeTile(),
                  ],
                ),
                const SizedBox(height: 24),

                // Account section
                _buildSection(
                  title: 'Account',
                  children: [
                    _buildChangePasswordTile(),
                    _buildPrivacyTile(),
                    _buildAboutTile(),
                  ],
                ),
                const SizedBox(height: 24),

                // Sign out button
                _buildSignOutButton(),
                const SizedBox(height: 32),

                // App version
                Center(
                  child: Text(
                    'FairShare v1.0.0',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildProfileHeader(UserModel? user) {
    return GlassCard(
      glowColor: AppTheme.accentPrimary,
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppTheme.accentPrimary.withOpacity(0.2),
                child: user?.photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          user!.photoUrl!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildInitials(user),
                        ),
                      )
                    : _buildInitials(user),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.bgCard, width: 2),
                  ),
                  child: InkWell(
                    onTap: _changePhoto,
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            user != null
              ? (user.displayName ?? user.email.split('@').first)
              : 'User',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            user?.email ?? '',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(UserModel? user) {
    final initials = user?.initials ?? '?';
    return Text(
      initials,
      style: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppTheme.accentPrimary,
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
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
              color: AppTheme.textSecondary,
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

  Widget _buildNameTile(UserModel? user) {
    if (_isEditing) {
      return ListTile(
        leading: const Icon(Icons.person_outline),
        title: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Display name',
            contentPadding: EdgeInsets.zero,
          ),
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppTheme.textPrimary,
          ),
        ),
      );
    }

    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: const Text('Display Name'),
      subtitle: Text(user?.displayName ?? 'Not set'),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => setState(() => _isEditing = true),
      ),
    );
  }

  Widget _buildEmailTile(UserModel? user) {
    return ListTile(
      leading: const Icon(Icons.email_outlined),
      title: const Text('Email'),
      subtitle: Text(user?.email ?? ''),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'Verified',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.successColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyTile() {
    return ListTile(
      leading: const Icon(Icons.attach_money),
      title: const Text('Default Currency'),
      subtitle: Text(_selectedCurrency),
      trailing: const Icon(Icons.chevron_right),
      onTap: _selectCurrency,
    );
  }

  Widget _buildNotificationsTile() {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: const Text('Push Notifications'),
      subtitle: const Text('Get notified about new expenses'),
      value: true, // TODO: Implement actual notifications setting
      onChanged: (value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications coming soon')),
        );
      },
    );
  }

  Widget _buildThemeTile() {
    return ListTile(
      leading: const Icon(Icons.dark_mode_outlined),
      title: const Text('Theme'),
      subtitle: const Text('Dark'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.bgTertiary,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'Only',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildChangePasswordTile() {
    return ListTile(
      leading: const Icon(Icons.lock_outline),
      title: const Text('Change Password'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _changePassword,
    );
  }

  Widget _buildPrivacyTile() {
    return ListTile(
      leading: const Icon(Icons.privacy_tip_outlined),
      title: const Text('Privacy Policy'),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening privacy policy...')),
        );
      },
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('About FairShare'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showAbout,
    );
  }

  Widget _buildSignOutButton() {
    return OutlinedButton.icon(
      onPressed: _confirmSignOut,
      icon: const Icon(Icons.logout, color: AppTheme.errorColor),
      label: Text(
        'Sign Out',
        style: GoogleFonts.inter(
          color: AppTheme.errorColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppTheme.errorColor.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  void _changePhoto() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo upload coming soon')),
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
            trailing: _selectedCurrency == currency
                ? const Icon(Icons.check, color: AppTheme.accentPrimary)
                : null,
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _selectedCurrency = currency;
                _isEditing = true;
              });
            },
          )),
        ],
      ),
    );
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text(
          'We will send a password reset link to your email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final email = context.read<AuthService>().currentUser?.email;
              if (email != null) {
                final success = await context
                    .read<AuthService>()
                    .sendPasswordResetEmail(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Password reset email sent!'
                            : 'Failed to send reset email',
                      ),
                      backgroundColor:
                          success ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'FairShare',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.accentPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.account_balance_wallet,
          size: 48,
          color: AppTheme.accentPrimary,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        Text(
          'FairShare is a free, open-source expense splitting app. '
          'No ads, no premium tiers, just fair splitting.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await context.read<AuthService>().signOut();
  }

  Future<void> _saveProfile() async {
    final authService = context.read<AuthService>();
    final success = await authService.updateProfile(
      displayName: _nameController.text.trim(),
      defaultCurrency: _selectedCurrency,
    );

    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Profile updated' : 'Failed to update profile',
          ),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }
}
