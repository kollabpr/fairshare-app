import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/activity_model.dart';
import '../../services/auth_service.dart';
import '../../services/activity_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_indicator.dart';
import '../groups/group_detail_screen.dart';
import '../../services/groups_service.dart';

/// Activity Feed Screen - Shows user's recent activities
class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when opening the feed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllAsRead();
    });
  }

  void _markAllAsRead() {
    final auth = context.read<AuthService>();
    final userId = auth.userId;
    if (userId != null) {
      context.read<ActivityService>().markAllAsRead(userId);
    }
  }

  Future<void> _onRefresh() async {
    final auth = context.read<AuthService>();
    final userId = auth.userId;
    if (userId != null) {
      await context.read<ActivityService>().getActivities(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userId = auth.userId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: Text(
          'Activity',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<List<ActivityModel>>(
        stream: context.read<ActivityService>().streamActivities(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: LoadingIndicator(message: 'Loading activities...'),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Something went wrong',
                message: 'Could not load your activities.',
                actionLabel: 'Try Again',
                onAction: _onRefresh,
              ),
            );
          }

          final activities = snapshot.data ?? [];

          if (activities.isEmpty) {
            return _buildEmptyState();
          }

          // Group activities by date
          final activityService = context.read<ActivityService>();
          final groupedActivities = activityService.groupActivitiesByDate(activities);
          final dateGroups = groupedActivities.keys.toList();

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppTheme.accentPrimary,
            backgroundColor: AppTheme.bgCard,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: dateGroups.length,
              itemBuilder: (context, groupIndex) {
                final dateGroup = dateGroups[groupIndex];
                final groupActivities = groupedActivities[dateGroup]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateHeader(dateGroup),
                    ...groupActivities.map((activity) => _ActivityTile(
                      activity: activity,
                      onTap: () => _onActivityTap(activity),
                    )),
                    if (groupIndex < dateGroups.length - 1)
                      const SizedBox(height: 8),
                  ],
                );
              },
            ),
          );
        },
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
            // Fun illustration - stacked notification bells
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentPrimary.withOpacity(0.1),
                    AppTheme.accentBlue.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 20,
                    left: 25,
                    child: Icon(
                      Icons.notifications_outlined,
                      size: 32,
                      color: AppTheme.textMuted.withOpacity(0.3),
                    ),
                  ),
                  Positioned(
                    bottom: 25,
                    right: 20,
                    child: Icon(
                      Icons.notifications_outlined,
                      size: 40,
                      color: AppTheme.textMuted.withOpacity(0.5),
                    ),
                  ),
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 48,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No activity yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you or your group members add\nexpenses or make payments, you\'ll see\nthe activity here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Subtle hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: AppTheme.accentOrange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Start by adding an expense!',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String dateGroup) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        dateGroup,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _onActivityTap(ActivityModel activity) async {
    // Navigate to the related item based on activity type
    if (activity.groupId != null) {
      final groupsService = context.read<GroupsService>();
      final group = await groupsService.getGroup(activity.groupId!);
      if (group != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(group: group),
          ),
        );
      }
    }
  }
}

/// Individual activity tile widget
class _ActivityTile extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: activity.isRead ? AppTheme.bgCard : AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activity.isRead ? AppTheme.borderColor : activity.color.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity icon
                _buildIcon(),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      Text(
                        activity.description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: activity.isRead ? FontWeight.w400 : FontWeight.w500,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Meta info row
                      Row(
                        children: [
                          // Time
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activity.relativeTime,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),

                          // Group name if available
                          if (activity.groupName != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.group_outlined,
                              size: 12,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                activity.groupName!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount badge if applicable
                if (activity.amount != null) ...[
                  const SizedBox(width: 12),
                  _buildAmountBadge(),
                ],

                // Unread indicator
                if (!activity.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: activity.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: activity.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        activity.icon,
        color: activity.color,
        size: 22,
      ),
    );
  }

  Widget _buildAmountBadge() {
    final isPositive = activity.type == ActivityType.settlementRecorded ||
        activity.type == ActivityType.settlementConfirmed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPositive
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.accentOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        activity.formattedAmount ?? '',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isPositive ? AppTheme.successColor : AppTheme.accentOrange,
        ),
      ),
    );
  }
}

/// Badge widget to show unread activity count
class ActivityBadge extends StatelessWidget {
  final int count;
  final double size;

  const ActivityBadge({
    super.key,
    required this.count,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
      ),
      padding: EdgeInsets.symmetric(horizontal: count > 9 ? 4 : 0),
      decoration: const BoxDecoration(
        color: AppTheme.errorColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: GoogleFonts.inter(
            fontSize: size * 0.6,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Icon button with activity badge overlay
class ActivityIconButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ActivityIconButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userId = auth.userId;

    if (userId == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: onPressed,
      );
    }

    return StreamBuilder<int>(
      stream: context.read<ActivityService>().streamUnreadCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: onPressed,
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: ActivityBadge(count: count),
              ),
          ],
        );
      },
    );
  }
}
