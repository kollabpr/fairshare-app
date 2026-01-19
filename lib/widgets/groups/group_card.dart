import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/group_model.dart';
import '../common/balance_badge.dart';

/// Group card for list display
class GroupCard extends StatelessWidget {
  final GroupModel group;
  final double? userBalance;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GroupCard({
    super.key,
    required this.group,
    this.userBalance,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Group icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: group.themeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  group.icon,
                  color: group.themeColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // Group details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount} member${group.memberCount != 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        if (group.totalExpenses > 0) ...[
                          Text(
                            ' \u2022 ',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                          Text(
                            '${group.currencySymbol}${group.totalExpenses.toStringAsFixed(0)} total',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Balance badge
              if (userBalance != null) ...[
                const SizedBox(width: 12),
                BalanceBadge(balance: userBalance!, currencySymbol: group.currencySymbol),
              ] else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact group list item
class GroupListItem extends StatelessWidget {
  final GroupModel group;
  final VoidCallback? onTap;

  const GroupListItem({
    super.key,
    required this.group,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: group.themeColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          group.icon,
          color: group.themeColor,
          size: 20,
        ),
      ),
      title: Text(
        group.name,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        '${group.memberCount} members',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppTheme.textMuted,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textMuted,
      ),
    );
  }
}
