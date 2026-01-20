import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'expense_model.dart';
import 'group_model.dart';

/// Direct expense model - represents an expense between exactly 2 people (not in a group)
/// Stored at /directExpenses/{expenseId}
class DirectExpenseModel {
  final String id;
  final String description;
  final double amount;
  final String currencyCode;
  final String payerId;             // User ID who paid
  final String payerEmail;          // Payer's email for display
  final String? payerName;          // Payer's display name
  final String participantId;       // The other user's ID
  final String participantEmail;    // The other user's email
  final String? participantName;    // The other user's display name
  final List<String> participants;  // Array of both user IDs for querying
  final DateTime date;
  final String category;
  final String? notes;
  final String? receiptImageUrl;
  final SplitType splitType;
  final double payerOwedAmount;     // How much the payer owes (usually 0 or partial)
  final double participantOwedAmount; // How much the participant owes
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isSettled;             // True if this expense is fully settled
  final DateTime? settledAt;

  DirectExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    this.currencyCode = 'USD',
    required this.payerId,
    required this.payerEmail,
    this.payerName,
    required this.participantId,
    required this.participantEmail,
    this.participantName,
    required this.participants,
    required this.date,
    this.category = 'other',
    this.notes,
    this.receiptImageUrl,
    this.splitType = SplitType.equal,
    required this.payerOwedAmount,
    required this.participantOwedAmount,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSettled = false,
    this.settledAt,
  });

  /// Create from Firestore document
  factory DirectExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DirectExpenseModel(
      id: doc.id,
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currencyCode: data['currencyCode'] ?? 'USD',
      payerId: data['payerId'] ?? '',
      payerEmail: data['payerEmail'] ?? '',
      payerName: data['payerName'],
      participantId: data['participantId'] ?? '',
      participantEmail: data['participantEmail'] ?? '',
      participantName: data['participantName'],
      participants: List<String>.from(data['participants'] ?? []),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: data['category'] ?? 'other',
      notes: data['notes'],
      receiptImageUrl: data['receiptImageUrl'],
      splitType: SplitType.values.firstWhere(
        (e) => e.name == (data['splitType'] ?? 'equal'),
        orElse: () => SplitType.equal,
      ),
      payerOwedAmount: (data['payerOwedAmount'] ?? 0).toDouble(),
      participantOwedAmount: (data['participantOwedAmount'] ?? 0).toDouble(),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: data['isDeleted'] ?? false,
      isSettled: data['isSettled'] ?? false,
      settledAt: (data['settledAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'amount': amount,
      'currencyCode': currencyCode,
      'payerId': payerId,
      'payerEmail': payerEmail,
      'payerName': payerName,
      'participantId': participantId,
      'participantEmail': participantEmail,
      'participantName': participantName,
      'participants': participants,
      'date': Timestamp.fromDate(date),
      'category': category,
      'notes': notes,
      'receiptImageUrl': receiptImageUrl,
      'splitType': splitType.name,
      'payerOwedAmount': payerOwedAmount,
      'participantOwedAmount': participantOwedAmount,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'isSettled': isSettled,
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
    };
  }

  /// Create a copy with updated fields
  DirectExpenseModel copyWith({
    String? description,
    double? amount,
    String? currencyCode,
    String? payerName,
    String? participantName,
    DateTime? date,
    String? category,
    String? notes,
    String? receiptImageUrl,
    SplitType? splitType,
    double? payerOwedAmount,
    double? participantOwedAmount,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isSettled,
    DateTime? settledAt,
  }) {
    return DirectExpenseModel(
      id: id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      payerId: payerId,
      payerEmail: payerEmail,
      payerName: payerName ?? this.payerName,
      participantId: participantId,
      participantEmail: participantEmail,
      participantName: participantName ?? this.participantName,
      participants: participants,
      date: date ?? this.date,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      splitType: splitType ?? this.splitType,
      payerOwedAmount: payerOwedAmount ?? this.payerOwedAmount,
      participantOwedAmount: participantOwedAmount ?? this.participantOwedAmount,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
    );
  }

  /// Get the category icon
  IconData get categoryIcon => ExpenseCategory.getIcon(category);

  /// Get the category label
  String get categoryLabel => ExpenseCategory.getLabel(category);

  /// Get currency symbol
  String get currencySymbol {
    final symbols = {
      'USD': '\$',
      'EUR': '\u20AC',
      'GBP': '\u00A3',
      'JPY': '\u00A5',
      'INR': '\u20B9',
    };
    return symbols[currencyCode] ?? '\$';
  }

  /// Format amount with currency
  String get formattedAmount => '$currencySymbol${amount.toStringAsFixed(2)}';

  /// Get the other person's ID (not the current user)
  String getOtherUserId(String currentUserId) {
    return currentUserId == payerId ? participantId : payerId;
  }

  /// Get the other person's name
  String getOtherUserName(String currentUserId) {
    if (currentUserId == payerId) {
      return participantName ?? participantEmail.split('@').first;
    }
    return payerName ?? payerEmail.split('@').first;
  }

  /// Get the balance impact for a specific user
  /// Positive = they are owed money, negative = they owe money
  double getBalanceForUser(String userId) {
    if (userId == payerId) {
      // Payer paid the full amount, they're owed the participant's share
      return participantOwedAmount;
    } else {
      // Participant owes money
      return -participantOwedAmount;
    }
  }

  /// Get formatted balance for a specific user
  String getFormattedBalanceForUser(String userId) {
    final balance = getBalanceForUser(userId);
    if (balance.abs() < 0.01) return 'settled';
    final absBalance = balance.abs().toStringAsFixed(2);
    if (balance > 0) {
      return 'lent $currencySymbol$absBalance';
    }
    return 'borrowed $currencySymbol$absBalance';
  }

  /// Format date as relative or absolute
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Direct settlement model - represents a payment between two friends (not in a group)
/// Stored at /directSettlements/{settlementId}
class DirectSettlementModel {
  final String id;
  final String fromUserId;          // Who paid
  final String fromEmail;           // Payer's email
  final String? fromName;           // Payer's name
  final String toUserId;            // Who received
  final String toEmail;             // Recipient's email
  final String? toName;             // Recipient's name
  final List<String> participants;  // Array of both user IDs for querying
  final double amount;
  final String currencyCode;
  final DateTime date;
  final String? notes;
  final String? proofImageUrl;
  final String createdBy;
  final DateTime createdAt;
  final bool isConfirmed;
  final DateTime? confirmedAt;

  DirectSettlementModel({
    required this.id,
    required this.fromUserId,
    required this.fromEmail,
    this.fromName,
    required this.toUserId,
    required this.toEmail,
    this.toName,
    required this.participants,
    required this.amount,
    this.currencyCode = 'USD',
    required this.date,
    this.notes,
    this.proofImageUrl,
    required this.createdBy,
    required this.createdAt,
    this.isConfirmed = false,
    this.confirmedAt,
  });

  /// Create from Firestore document
  factory DirectSettlementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DirectSettlementModel(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      fromEmail: data['fromEmail'] ?? '',
      fromName: data['fromName'],
      toUserId: data['toUserId'] ?? '',
      toEmail: data['toEmail'] ?? '',
      toName: data['toName'],
      participants: List<String>.from(data['participants'] ?? []),
      amount: (data['amount'] ?? 0).toDouble(),
      currencyCode: data['currencyCode'] ?? 'USD',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
      proofImageUrl: data['proofImageUrl'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isConfirmed: data['isConfirmed'] ?? false,
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'fromEmail': fromEmail,
      'fromName': fromName,
      'toUserId': toUserId,
      'toEmail': toEmail,
      'toName': toName,
      'participants': participants,
      'amount': amount,
      'currencyCode': currencyCode,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'proofImageUrl': proofImageUrl,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isConfirmed': isConfirmed,
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
    };
  }

  /// Create a copy with updated fields
  DirectSettlementModel copyWith({
    double? amount,
    DateTime? date,
    String? notes,
    String? proofImageUrl,
    bool? isConfirmed,
    DateTime? confirmedAt,
  }) {
    return DirectSettlementModel(
      id: id,
      fromUserId: fromUserId,
      fromEmail: fromEmail,
      fromName: fromName,
      toUserId: toUserId,
      toEmail: toEmail,
      toName: toName,
      participants: participants,
      amount: amount ?? this.amount,
      currencyCode: currencyCode,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  /// Get currency symbol
  String get currencySymbol {
    final symbols = {
      'USD': '\$',
      'EUR': '\u20AC',
      'GBP': '\u00A3',
    };
    return symbols[currencyCode] ?? '\$';
  }

  /// Format amount with currency
  String get formattedAmount => '$currencySymbol${amount.toStringAsFixed(2)}';

  /// Get the other person's ID (not the current user)
  String getOtherUserId(String currentUserId) {
    return currentUserId == fromUserId ? toUserId : fromUserId;
  }

  /// Get the balance impact for a specific user
  double getBalanceForUser(String userId) {
    if (userId == fromUserId) {
      // Payer paid, so they're owed this amount
      return amount;
    } else {
      // Receiver received, so they owe this amount
      return -amount;
    }
  }

  /// Check if this settlement has proof attached
  bool get hasProof => proofImageUrl != null && proofImageUrl!.isNotEmpty;

  /// Get status text
  String get statusText {
    if (isConfirmed) return 'Confirmed';
    if (hasProof) return 'Proof attached';
    return 'Pending confirmation';
  }
}
