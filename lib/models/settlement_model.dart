import 'package:cloud_firestore/cloud_firestore.dart';

/// Settlement model - represents a payment between group members
class SettlementModel {
  final String id;
  final String groupId;
  final String fromMemberId;      // Who paid
  final String toMemberId;        // Who received
  final String? fromUserId;       // Actual user ID
  final String? toUserId;         // Actual user ID
  final double amount;
  final String currencyCode;
  final DateTime date;
  final String? notes;
  final String? proofImageUrl;    // Venmo/payment screenshot
  final String createdBy;
  final DateTime createdAt;
  final bool isConfirmed;         // Recipient confirmed
  final DateTime? confirmedAt;

  SettlementModel({
    required this.id,
    required this.groupId,
    required this.fromMemberId,
    required this.toMemberId,
    this.fromUserId,
    this.toUserId,
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
  factory SettlementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SettlementModel(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      fromMemberId: data['fromMemberId'] ?? '',
      toMemberId: data['toMemberId'] ?? '',
      fromUserId: data['fromUserId'],
      toUserId: data['toUserId'],
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
      'groupId': groupId,
      'fromMemberId': fromMemberId,
      'toMemberId': toMemberId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
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
  SettlementModel copyWith({
    double? amount,
    DateTime? date,
    String? notes,
    String? proofImageUrl,
    bool? isConfirmed,
    DateTime? confirmedAt,
  }) {
    return SettlementModel(
      id: id,
      groupId: groupId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      fromUserId: fromUserId,
      toUserId: toUserId,
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

  /// Check if this settlement has proof attached
  bool get hasProof => proofImageUrl != null && proofImageUrl!.isNotEmpty;

  /// Get status text
  String get statusText {
    if (isConfirmed) return 'Confirmed';
    if (hasProof) return 'Proof attached';
    return 'Pending confirmation';
  }
}
