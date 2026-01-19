import 'package:cloud_firestore/cloud_firestore.dart';

/// Split model - represents how much each member owes for an expense
class SplitModel {
  final String id;
  final String expenseId;
  final String memberId;          // Group member ID
  final String? userId;           // Actual user ID if exists
  final double owedAmount;        // How much they owe for this expense
  final double paidAmount;        // How much they contributed upfront
  final double? percentage;       // If percentage split
  final int? shares;              // If shares-based split
  final bool isSettled;
  final DateTime? settledAt;

  SplitModel({
    required this.id,
    required this.expenseId,
    required this.memberId,
    this.userId,
    required this.owedAmount,
    this.paidAmount = 0.0,
    this.percentage,
    this.shares,
    this.isSettled = false,
    this.settledAt,
  });

  /// Create from Firestore document
  factory SplitModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SplitModel(
      id: doc.id,
      expenseId: data['expenseId'] ?? '',
      memberId: data['memberId'] ?? '',
      userId: data['userId'],
      owedAmount: (data['owedAmount'] ?? 0).toDouble(),
      paidAmount: (data['paidAmount'] ?? 0).toDouble(),
      percentage: data['percentage']?.toDouble(),
      shares: data['shares'],
      isSettled: data['isSettled'] ?? false,
      settledAt: (data['settledAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'expenseId': expenseId,
      'memberId': memberId,
      'userId': userId,
      'owedAmount': owedAmount,
      'paidAmount': paidAmount,
      'percentage': percentage,
      'shares': shares,
      'isSettled': isSettled,
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
    };
  }

  /// Create a copy with updated fields
  SplitModel copyWith({
    double? owedAmount,
    double? paidAmount,
    double? percentage,
    int? shares,
    bool? isSettled,
    DateTime? settledAt,
  }) {
    return SplitModel(
      id: id,
      expenseId: expenseId,
      memberId: memberId,
      userId: userId,
      owedAmount: owedAmount ?? this.owedAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
    );
  }

  /// Calculate net amount (positive = owes, negative = gets back)
  double get netAmount => owedAmount - paidAmount;

  /// Check if this member paid for the expense
  bool get isPayer => paidAmount > 0;

  /// Check if this member owes money
  bool get owes => netAmount > 0.01;

  /// Check if this member gets money back
  bool get getsBack => netAmount < -0.01;
}
