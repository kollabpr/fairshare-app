import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'group_model.dart';

/// Expense categories
class ExpenseCategory {
  static const String food = 'food';
  static const String groceries = 'groceries';
  static const String transportation = 'transportation';
  static const String utilities = 'utilities';
  static const String rent = 'rent';
  static const String entertainment = 'entertainment';
  static const String shopping = 'shopping';
  static const String travel = 'travel';
  static const String health = 'health';
  static const String other = 'other';

  static const List<String> all = [
    food,
    groceries,
    transportation,
    utilities,
    rent,
    entertainment,
    shopping,
    travel,
    health,
    other,
  ];

  static IconData getIcon(String category) {
    switch (category) {
      case food:
        return Icons.restaurant_rounded;
      case groceries:
        return Icons.shopping_cart_rounded;
      case transportation:
        return Icons.directions_car_rounded;
      case utilities:
        return Icons.bolt_rounded;
      case rent:
        return Icons.home_rounded;
      case entertainment:
        return Icons.movie_rounded;
      case shopping:
        return Icons.shopping_bag_rounded;
      case travel:
        return Icons.flight_rounded;
      case health:
        return Icons.health_and_safety_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  static String getLabel(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }
}

/// Expense model - represents a shared expense in a group
class ExpenseModel {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String currencyCode;
  final String payerId;           // Member ID who paid
  final String? payerUserId;      // Actual user ID if not ghost
  final DateTime date;
  final String category;
  final String? notes;
  final String? receiptImageUrl;  // Scanned receipt
  final String? proofImageUrl;    // Payment proof (Venmo screenshot)
  final bool isSettlement;        // True = payment between users
  final String? settlementFromId; // If settlement, who paid
  final String? settlementToId;   // If settlement, who received
  final SplitType splitType;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    this.currencyCode = 'USD',
    required this.payerId,
    this.payerUserId,
    required this.date,
    this.category = 'other',
    this.notes,
    this.receiptImageUrl,
    this.proofImageUrl,
    this.isSettlement = false,
    this.settlementFromId,
    this.settlementToId,
    this.splitType = SplitType.equal,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Create from Firestore document
  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currencyCode: data['currencyCode'] ?? 'USD',
      payerId: data['payerId'] ?? '',
      payerUserId: data['payerUserId'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: data['category'] ?? 'other',
      notes: data['notes'],
      receiptImageUrl: data['receiptImageUrl'],
      proofImageUrl: data['proofImageUrl'],
      isSettlement: data['isSettlement'] ?? false,
      settlementFromId: data['settlementFromId'],
      settlementToId: data['settlementToId'],
      splitType: SplitType.values.firstWhere(
        (e) => e.name == (data['splitType'] ?? 'equal'),
        orElse: () => SplitType.equal,
      ),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'currencyCode': currencyCode,
      'payerId': payerId,
      'payerUserId': payerUserId,
      'date': Timestamp.fromDate(date),
      'category': category,
      'notes': notes,
      'receiptImageUrl': receiptImageUrl,
      'proofImageUrl': proofImageUrl,
      'isSettlement': isSettlement,
      'settlementFromId': settlementFromId,
      'settlementToId': settlementToId,
      'splitType': splitType.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
    };
  }

  /// Create a copy with updated fields
  ExpenseModel copyWith({
    String? description,
    double? amount,
    String? currencyCode,
    String? payerId,
    String? payerUserId,
    DateTime? date,
    String? category,
    String? notes,
    String? receiptImageUrl,
    String? proofImageUrl,
    bool? isSettlement,
    String? settlementFromId,
    String? settlementToId,
    SplitType? splitType,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return ExpenseModel(
      id: id,
      groupId: groupId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      payerId: payerId ?? this.payerId,
      payerUserId: payerUserId ?? this.payerUserId,
      date: date ?? this.date,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      isSettlement: isSettlement ?? this.isSettlement,
      settlementFromId: settlementFromId ?? this.settlementFromId,
      settlementToId: settlementToId ?? this.settlementToId,
      splitType: splitType ?? this.splitType,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
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
