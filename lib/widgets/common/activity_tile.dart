import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';

/// Activity types for the feed
enum ActivityType {
  expense,
  payment,
  groupJoin,
  groupLeave,
  settlement,
  reminder,
  other,
}

/// A Gen Z inspired activity tile for the activity feed with icon,
/// description, time ago, swipe actions, and subtle animations.
class ActivityTile extends StatefulWidget {
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? avatarName;
  final String? avatarUrl;
  final double? amount;
  final bool isPositive;
  final VoidCallback? onTap;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final String? swipeLeftLabel;
  final String? swipeRightLabel;
  final bool showSwipeHint;

  const ActivityTile({
    super.key,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.avatarName,
    this.avatarUrl,
    this.amount,
    this.isPositive = true,
    this.onTap,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.swipeLeftLabel,
    this.swipeRightLabel,
    this.showSwipeHint = false,
  });

  @override
  State<ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<ActivityTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIconForType() {
    switch (widget.type) {
      case ActivityType.expense:
        return Icons.receipt_long_rounded;
      case ActivityType.payment:
        return Icons.payments_rounded;
      case ActivityType.groupJoin:
        return Icons.person_add_rounded;
      case ActivityType.groupLeave:
        return Icons.person_remove_rounded;
      case ActivityType.settlement:
        return Icons.handshake_rounded;
      case ActivityType.reminder:
        return Icons.notifications_rounded;
      case ActivityType.other:
        return Icons.info_rounded;
    }
  }

  Color _getColorForType() {
    switch (widget.type) {
      case ActivityType.expense:
        return AppTheme.accentOrange;
      case ActivityType.payment:
        return AppTheme.accentPrimary;
      case ActivityType.groupJoin:
        return AppTheme.accentBlue;
      case ActivityType.groupLeave:
        return AppTheme.accentPink;
      case ActivityType.settlement:
        return AppTheme.accentPurple;
      case ActivityType.reminder:
        return AppTheme.accentYellow;
      case ActivityType.other:
        return AppTheme.textMuted;
    }
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(widget.timestamp);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '${mins}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '${days}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (widget.onSwipeLeft == null && widget.onSwipeRight == null) return;

    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-100.0, 100.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset > 60 && widget.onSwipeRight != null) {
      widget.onSwipeRight!();
    } else if (_dragOffset < -60 && widget.onSwipeLeft != null) {
      widget.onSwipeLeft!();
    }

    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForType();
    final icon = _getIconForType();
    final timeAgo = _getTimeAgo();

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              children: [
                // Swipe action backgrounds
                if (widget.onSwipeRight != null || widget.onSwipeLeft != null)
                  _buildSwipeBackground(color),

                // Main tile content
                AnimatedContainer(
                  duration: _isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(_dragOffset, 0, 0),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildIcon(icon, color),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    timeAgo,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.description,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (widget.amount != null) ...[
                                    const SizedBox(width: 8),
                                    _buildAmount(),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildAmount() {
    final color = widget.isPositive ? AppTheme.getBackColor : AppTheme.owesColor;
    final prefix = widget.isPositive ? '+' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$prefix\$${widget.amount!.abs().toStringAsFixed(2)}',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(Color color) {
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Right swipe action (appears on left)
            if (widget.onSwipeRight != null)
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _dragOffset > 30 ? 1.0 : 0.3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, color: Colors.white),
                        if (widget.swipeRightLabel != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            widget.swipeRightLabel!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            // Left swipe action (appears on right)
            if (widget.onSwipeLeft != null)
              Expanded(
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _dragOffset < -30 ? 1.0 : 0.3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.swipeLeftLabel != null) ...[
                          Text(
                            widget.swipeLeftLabel!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        const Icon(Icons.delete_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Activity feed section header
class ActivitySectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const ActivitySectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'See all',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty activity state
class EmptyActivityState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyActivityState({
    super.key,
    this.message = 'No activity yet',
    this.icon = Icons.inbox_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
