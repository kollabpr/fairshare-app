import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/settlement_model.dart';
import '../../models/group_member_model.dart';
import '../../services/splitting_service.dart';

/// Settlement/payment card
class SettlementCard extends StatelessWidget {
  final SettlementModel settlement;
  final GroupMemberModel? fromMember;
  final GroupMemberModel? toMember;
  final VoidCallback? onTap;
  final VoidCallback? onConfirm;

  const SettlementCard({
    super.key,
    required this.settlement,
    this.fromMember,
    this.toMember,
    this.onTap,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // From avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.owesColor.withOpacity(0.2),
                    child: Text(
                      fromMember?.initials ?? '?',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.owesColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Arrow and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              fromMember?.nickname ?? 'Unknown',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              toMember?.nickname ?? 'Unknown',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          settlement.statusText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: settlement.isConfirmed
                                ? AppTheme.successColor
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // To avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.getBackColor.withOpacity(0.2),
                    child: Text(
                      toMember?.initials ?? '?',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getBackColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    settlement.formattedAmount,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentPrimary,
                    ),
                  ),
                  if (!settlement.isConfirmed && onConfirm != null)
                    TextButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Confirm'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.successColor,
                      ),
                    ),
                  if (settlement.isConfirmed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppTheme.successColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Confirmed',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Suggested settlement tile (debt simplification result)
class SettlementSuggestionTile extends StatelessWidget {
  final SimplifiedDebt debt;
  final GroupMemberModel? fromMember;
  final GroupMemberModel? toMember;
  final String currencySymbol;
  final VoidCallback? onSettle;

  const SettlementSuggestionTile({
    super.key,
    required this.debt,
    this.fromMember,
    this.toMember,
    this.currencySymbol = '\$',
    this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // From member
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.owesColor.withOpacity(0.2),
              child: Text(
                fromMember?.initials ?? '?',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.owesColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Flow text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fromMember?.nickname ?? 'Someone'} pays',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    toMember?.nickname ?? 'Someone',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Text(
              '$currencySymbol${debt.amount.toStringAsFixed(2)}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentPrimary,
              ),
            ),
            const SizedBox(width: 12),
            // Settle button
            if (onSettle != null)
              IconButton(
                onPressed: onSettle,
                icon: const Icon(Icons.check_circle_outline),
                color: AppTheme.successColor,
                tooltip: 'Record payment',
              ),
          ],
        ),
      ),
    );
  }
}
