import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Split type enum for how expenses are divided
enum SplitType {
  equal,      // Split equally among all participants
  exact,      // Exact amounts specified
  percentage, // Percentage-based split
  shares,     // Share-based split (e.g., 2 shares vs 1 share)
  equity,     // Income-based "fair" split using salary weights
}

/// Group model for expense sharing groups
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final String currencyCode;
  final String? headerImageUrl;
  final String? iconName;
  final String? colorHex;
  final bool simplifyDebts;
  final SplitType defaultSplitType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final int memberCount;
  final double totalExpenses;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    this.currencyCode = 'USD',
    this.headerImageUrl,
    this.iconName,
    this.colorHex,
    this.simplifyDebts = true,
    this.defaultSplitType = SplitType.equal,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.memberCount = 1,
    this.totalExpenses = 0.0,
  });

  /// Create from Firestore document
  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      createdBy: data['createdBy'] ?? '',
      currencyCode: data['currencyCode'] ?? 'USD',
      headerImageUrl: data['headerImageUrl'],
      iconName: data['iconName'],
      colorHex: data['colorHex'],
      simplifyDebts: data['simplifyDebts'] ?? true,
      defaultSplitType: SplitType.values.firstWhere(
        (e) => e.name == (data['defaultSplitType'] ?? 'equal'),
        orElse: () => SplitType.equal,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isArchived: data['isArchived'] ?? false,
      memberCount: data['memberCount'] ?? 1,
      totalExpenses: (data['totalExpenses'] ?? 0).toDouble(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'currencyCode': currencyCode,
      'headerImageUrl': headerImageUrl,
      'iconName': iconName,
      'colorHex': colorHex,
      'simplifyDebts': simplifyDebts,
      'defaultSplitType': defaultSplitType.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isArchived': isArchived,
      'memberCount': memberCount,
      'totalExpenses': totalExpenses,
    };
  }

  /// Create a copy with updated fields
  GroupModel copyWith({
    String? name,
    String? description,
    String? currencyCode,
    String? headerImageUrl,
    String? iconName,
    String? colorHex,
    bool? simplifyDebts,
    SplitType? defaultSplitType,
    DateTime? updatedAt,
    bool? isArchived,
    int? memberCount,
    double? totalExpenses,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy,
      currencyCode: currencyCode ?? this.currencyCode,
      headerImageUrl: headerImageUrl ?? this.headerImageUrl,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      simplifyDebts: simplifyDebts ?? this.simplifyDebts,
      defaultSplitType: defaultSplitType ?? this.defaultSplitType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      memberCount: memberCount ?? this.memberCount,
      totalExpenses: totalExpenses ?? this.totalExpenses,
    );
  }

  /// Get the theme color for this group
  Color get themeColor {
    if (colorHex != null && colorHex!.isNotEmpty) {
      try {
        return Color(int.parse(colorHex!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return const Color(0xFF6366f1); // Default indigo
  }

  /// Get the icon for this group
  IconData get icon {
    final iconMap = {
      'home': Icons.home_rounded,
      'trip': Icons.flight_rounded,
      'food': Icons.restaurant_rounded,
      'couple': Icons.favorite_rounded,
      'friends': Icons.group_rounded,
      'work': Icons.work_rounded,
      'party': Icons.celebration_rounded,
      'shopping': Icons.shopping_bag_rounded,
    };
    return iconMap[iconName] ?? Icons.group_rounded;
  }

  /// Get currency symbol
  String get currencySymbol {
    final symbols = {
      'USD': '\$',
      'EUR': '\u20AC',
      'GBP': '\u00A3',
      'JPY': '\u00A5',
      'INR': '\u20B9',
      'CAD': 'C\$',
      'AUD': 'A\$',
    };
    return symbols[currencyCode] ?? '\$';
  }

  /// Format amount with currency
  String formatAmount(double amount) {
    return '$currencySymbol${amount.abs().toStringAsFixed(2)}';
  }
}
