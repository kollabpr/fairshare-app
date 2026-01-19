import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/group_member_model.dart';

/// Reusable member avatar widget
class MemberAvatar extends StatelessWidget {
  final GroupMemberModel member;
  final double radius;
  final Color? backgroundColor;
  final bool showBorder;
  final bool showBalance;

  const MemberAvatar({
    super.key,
    required this.member,
    this.radius = 20,
    this.backgroundColor,
    this.showBorder = false,
    this.showBalance = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppTheme.accentPrimary.withOpacity(0.2);

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        member.initials,
        style: GoogleFonts.inter(
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w600,
          color: AppTheme.accentPrimary,
        ),
      ),
    );

    if (showBorder) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: member.isGhostUser ? AppTheme.textMuted : AppTheme.accentPrimary,
            width: 2,
          ),
        ),
        child: avatar,
      );
    }

    if (showBalance && member.balance.abs() > 0.01) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.getBalanceColor(member.balance),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                member.balance > 0 ? '+' : '-',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }
}

/// Stack of member avatars
class MemberAvatarStack extends StatelessWidget {
  final List<GroupMemberModel> members;
  final int maxDisplay;
  final double radius;

  const MemberAvatarStack({
    super.key,
    required this.members,
    this.maxDisplay = 4,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final displayMembers = members.take(maxDisplay).toList();
    final overflow = members.length - maxDisplay;

    return SizedBox(
      height: radius * 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < displayMembers.length; i++)
            Transform.translate(
              offset: Offset(-i * radius * 0.6, 0),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.bgPrimary, width: 2),
                ),
                child: MemberAvatar(
                  member: displayMembers[i],
                  radius: radius,
                ),
              ),
            ),
          if (overflow > 0)
            Transform.translate(
              offset: Offset(-displayMembers.length * radius * 0.6, 0),
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.bgPrimary, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$overflow',
                    style: GoogleFonts.inter(
                      fontSize: radius * 0.6,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
