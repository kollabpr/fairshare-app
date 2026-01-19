import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

/// A badge widget that displays a balance amount with appropriate color coding
/// Green for positive (gets back), Red for negative (owes), Gray for zero
class BalanceBadge extends StatelessWidget {
  final double balance;
  final String currencySymbol;
  final double fontSize;
  final bool showSign;
  final bool compact;

  const BalanceBadge({
    super.key,
    required this.balance,
    this.currencySymbol = '\$',
    this.fontSize = 14,
    this.showSign = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getBalanceColor(balance);
    final absBalance = balance.abs();

    String text;
    if (balance.abs() < 0.01) {
      text = 'settled';
    } else if (showSign) {
      text = balance > 0
          ? '+$currencySymbol${absBalance.toStringAsFixed(2)}'
          : '-$currencySymbol${absBalance.toStringAsFixed(2)}';
    } else {
      text = '$currencySymbol${absBalance.toStringAsFixed(2)}';
    }

    if (compact) {
      return Text(
        text,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
