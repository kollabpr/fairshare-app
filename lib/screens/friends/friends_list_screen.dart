import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';
import '../../models/group_model.dart';
import '../../services/auth_service.dart';
import '../../services/groups_service.dart';
import '../groups/group_detail_screen.dart';
import '../settlements/settle_up_screen.dart';

/// Friends list screen - shows all friends across groups with balances
class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<_FriendData> _allFriends = [];
  List<_FriendData> _filteredFriends = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterFriends();
    });
  }

  void _filterFriends() {
    if (_searchQuery.isEmpty) {
      _filteredFriends = List.from(_allFriends);
    } else {
      _filteredFriends = _allFriends
          .where((f) => f.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);

    try {
      final userId = context.read<AuthService>().userId;
      if (userId == null) return;

      final groupsService = context.read<GroupsService>();
      final groups = groupsService.groups;

      final Map<String, _FriendData> friendsMap = {};

      for (final group in groups) {
        final members = await groupsService.getMembers(group.id);

        for (final member in members) {
          // Skip current user
          if (member.userId == userId) continue;

          final key = member.userId ?? member.id;

          if (friendsMap.containsKey(key)) {
            // Update existing friend data
            final existing = friendsMap[key]!;
            friendsMap[key] = _FriendData(
              id: key,
              name: member.nickname,
              initials: member.initials,
              email: member.email,
              isGhost: member.isGhostUser,
              totalBalance: existing.totalBalance + member.balance,
              groups: [...existing.groups, _GroupBalance(group, member.balance)],
            );
          } else {
            // Add new friend
            friendsMap[key] = _FriendData(
              id: key,
              name: member.nickname,
              initials: member.initials,
              email: member.email,
              isGhost: member.isGhostUser,
              totalBalance: member.balance,
              groups: [_GroupBalance(group, member.balance)],
            );
          }
        }
      }

      // Sort by total balance (descending by absolute value)
      final friendsList = friendsMap.values.toList();
      friendsList.sort((a, b) => b.totalBalance.abs().compareTo(a.totalBalance.abs()));

      setState(() {
        _allFriends = friendsList;
        _filterFriends();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading friends: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 70,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.bgPrimary,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Friends',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                onPressed: _showAddFriendOptions,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: AppTheme.accentPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Search bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchBarDelegate(
              searchController: _searchController,
              onClear: () {
                _searchController.clear();
              },
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accentPrimary,
                ),
              ),
            )
          else if (_filteredFriends.isEmpty && _allFriends.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else if (_filteredFriends.isEmpty)
            SliverFillRemaining(
              child: _buildNoResultsState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0) {
                      // Pending requests section (placeholder)
                      return const SizedBox.shrink();
                    }
                    final friendIndex = index - 1;
                    if (friendIndex >= _filteredFriends.length) {
                      return const SizedBox(height: 100);
                    }
                    return AnimatedListItem(
                      index: friendIndex,
                      child: _FriendTile(
                        friend: _filteredFriends[friendIndex],
                        onTap: () => _showFriendDetails(_filteredFriends[friendIndex]),
                        onSettleUp: () => _handleSettleUp(_filteredFriends[friendIndex]),
                      ),
                    );
                  },
                  childCount: _filteredFriends.length + 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 44,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No friends yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add members to your groups to start\nsplitting expenses with friends.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddFriendOptions,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Friend'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
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

  void _showAddFriendOptions() {
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
            Text(
              'Add Friend',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _AddFriendOption(
              icon: Icons.group_add_rounded,
              title: 'Add to a Group',
              subtitle: 'Add a friend to an existing group',
              onTap: () {
                Navigator.pop(context);
                _showGroupSelectionForAddFriend();
              },
            ),
            const SizedBox(height: 12),
            _AddFriendOption(
              icon: Icons.share_rounded,
              title: 'Share Invite Link',
              subtitle: 'Send a link to join FairShare',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invite link copied to clipboard!'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _AddFriendOption(
              icon: Icons.contacts_rounded,
              title: 'From Contacts',
              subtitle: 'Import friends from your contacts',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact import coming soon!'),
                    backgroundColor: AppTheme.bgCard,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showGroupSelectionForAddFriend() {
    final groups = context.read<GroupsService>().groups;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a group first to add friends'),
          backgroundColor: AppTheme.bgCard,
        ),
      );
      return;
    }

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
              'Select a Group',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...groups.map((group) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: group.themeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      group.icon,
                      color: group.themeColor,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    group.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppTheme.textMuted,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to group detail to add member
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(group: group),
                      ),
                    );
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFriendDetails(_FriendData friend) {
    HapticFeedback.lightImpact();

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

              // Friend header
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.getBalanceColor(friend.totalBalance)
                        .withOpacity(0.15),
                    child: Text(
                      friend.initials,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getBalanceColor(friend.totalBalance),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              friend.name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (friend.isGhost) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.textMuted.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  'Not on FairShare',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (friend.email != null)
                          Text(
                            friend.email!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Total balance
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Balance',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getBalanceText(friend.totalBalance),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '\$${friend.totalBalance.abs().toStringAsFixed(2)}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getBalanceColor(friend.totalBalance),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Groups breakdown
              Text(
                'Balance by Group',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: friend.groups.length,
                  itemBuilder: (context, index) {
                    final groupBalance = friend.groups[index];
                    return _GroupBalanceTile(groupBalance: groupBalance);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              if (friend.totalBalance.abs() > 0.01)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleSettleUp(friend);
                    },
                    icon: const Icon(Icons.handshake_rounded),
                    label: const Text('Settle Up'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getBalanceText(double balance) {
    if (balance.abs() < 0.01) return "You're settled up";
    if (balance > 0) return 'They owe you';
    return 'You owe them';
  }

  void _handleSettleUp(_FriendData friend) {
    HapticFeedback.lightImpact();

    if (friend.groups.isEmpty) return;

    // If only one group, go directly to settle up
    if (friend.groups.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettleUpScreen(group: friend.groups.first.group),
        ),
      );
      return;
    }

    // Show group selection
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
              'Settle up in which group?',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...friend.groups
                .where((gb) => gb.balance.abs() > 0.01)
                .map((gb) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: gb.group.themeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          gb.group.icon,
                          color: gb.group.themeColor,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        gb.group.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '\$${gb.balance.abs().toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getBalanceColor(gb.balance),
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: AppTheme.textMuted,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettleUpScreen(group: gb.group),
                          ),
                        );
                      },
                    )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Search bar delegate for sliver header
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final VoidCallback onClear;

  _SearchBarDelegate({
    required this.searchController,
    required this.onClear,
  });

  @override
  double get minExtent => 80;

  @override
  double get maxExtent => 80;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppTheme.bgPrimary,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: TextField(
        controller: searchController,
        style: GoogleFonts.inter(
          color: AppTheme.textPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Search friends...',
          hintStyle: GoogleFonts.inter(
            color: AppTheme.textMuted,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.textMuted,
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: AppTheme.bgCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.accentPrimary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchBarDelegate oldDelegate) {
    return searchController != oldDelegate.searchController;
  }
}

/// Friend tile with swipe to settle
class _FriendTile extends StatelessWidget {
  final _FriendData friend;
  final VoidCallback onTap;
  final VoidCallback onSettleUp;

  const _FriendTile({
    required this.friend,
    required this.onTap,
    required this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final balanceColor = AppTheme.getBalanceColor(friend.totalBalance);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(friend.id),
        direction: friend.totalBalance.abs() > 0.01
            ? DismissDirection.endToStart
            : DismissDirection.none,
        background: Container(
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.handshake_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                'Settle Up',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          HapticFeedback.lightImpact();
          onSettleUp();
          return false;
        },
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
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: balanceColor.withOpacity(0.15),
                  child: Text(
                    friend.initials,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: balanceColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Name and groups
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            friend.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (friend.isGhost) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.person_off_rounded,
                              size: 14,
                              color: AppTheme.textMuted,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${friend.groups.length} group${friend.groups.length != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      friend.totalBalance.abs() < 0.01
                          ? 'Settled'
                          : '\$${friend.totalBalance.abs().toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: balanceColor,
                      ),
                    ),
                    if (friend.totalBalance.abs() >= 0.01)
                      Text(
                        friend.totalBalance > 0 ? 'owes you' : 'you owe',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Add friend option tile
class _AddFriendOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddFriendOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: AppTheme.accentPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
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
}

/// Group balance tile for friend details
class _GroupBalanceTile extends StatelessWidget {
  final _GroupBalance groupBalance;

  const _GroupBalanceTile({required this.groupBalance});

  @override
  Widget build(BuildContext context) {
    final balanceColor = AppTheme.getBalanceColor(groupBalance.balance);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: groupBalance.group.themeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              groupBalance.group.icon,
              color: groupBalance.group.themeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              groupBalance.group.name,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            groupBalance.balance.abs() < 0.01
                ? 'Settled'
                : '\$${groupBalance.balance.abs().toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: balanceColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Friend data model
class _FriendData {
  final String id;
  final String name;
  final String initials;
  final String? email;
  final bool isGhost;
  final double totalBalance;
  final List<_GroupBalance> groups;

  _FriendData({
    required this.id,
    required this.name,
    required this.initials,
    this.email,
    required this.isGhost,
    required this.totalBalance,
    required this.groups,
  });
}

/// Group balance for a friend
class _GroupBalance {
  final GroupModel group;
  final double balance;

  _GroupBalance(this.group, this.balance);
}
