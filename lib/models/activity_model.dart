import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Activity types for the activity feed
enum ActivityType {
  expenseAdded,
  expenseDeleted,
  settlementRecorded,
  settlementConfirmed,
  friendAdded,
  groupJoined,
  groupCreated,
  memberAdded,
}

/// Extension to add helpful methods to ActivityType
extension ActivityTypeExtension on ActivityType {
  /// Get display name for the activity type
  String get displayName {
    switch (this) {
      case ActivityType.expenseAdded:
        return 'Expense Added';
      case ActivityType.expenseDeleted:
        return 'Expense Deleted';
      case ActivityType.settlementRecorded:
        return 'Payment Recorded';
      case ActivityType.settlementConfirmed:
        return 'Payment Confirmed';
      case ActivityType.friendAdded:
        return 'Friend Added';
      case ActivityType.groupJoined:
        return 'Joined Group';
      case ActivityType.groupCreated:
        return 'Group Created';
      case ActivityType.memberAdded:
        return 'Member Added';
    }
  }

  /// Get icon for the activity type
  IconData get icon {
    switch (this) {
      case ActivityType.expenseAdded:
        return Icons.receipt_long_rounded;
      case ActivityType.expenseDeleted:
        return Icons.delete_outline_rounded;
      case ActivityType.settlementRecorded:
        return Icons.payments_rounded;
      case ActivityType.settlementConfirmed:
        return Icons.check_circle_rounded;
      case ActivityType.friendAdded:
        return Icons.person_add_rounded;
      case ActivityType.groupJoined:
        return Icons.group_add_rounded;
      case ActivityType.groupCreated:
        return Icons.add_circle_rounded;
      case ActivityType.memberAdded:
        return Icons.person_add_alt_1_rounded;
    }
  }

  /// Get color for the activity type
  Color get color {
    switch (this) {
      case ActivityType.expenseAdded:
        return AppTheme.accentOrange;
      case ActivityType.expenseDeleted:
        return AppTheme.errorColor;
      case ActivityType.settlementRecorded:
        return AppTheme.accentBlue;
      case ActivityType.settlementConfirmed:
        return AppTheme.successColor;
      case ActivityType.friendAdded:
        return AppTheme.accentPurple;
      case ActivityType.groupJoined:
        return AppTheme.accentPrimary;
      case ActivityType.groupCreated:
        return AppTheme.accentSecondary;
      case ActivityType.memberAdded:
        return AppTheme.accentPink;
    }
  }

  /// Get verb for activity description
  String get verb {
    switch (this) {
      case ActivityType.expenseAdded:
        return 'added an expense';
      case ActivityType.expenseDeleted:
        return 'deleted an expense';
      case ActivityType.settlementRecorded:
        return 'recorded a payment';
      case ActivityType.settlementConfirmed:
        return 'confirmed a payment';
      case ActivityType.friendAdded:
        return 'added a friend';
      case ActivityType.groupJoined:
        return 'joined a group';
      case ActivityType.groupCreated:
        return 'created a group';
      case ActivityType.memberAdded:
        return 'added a member';
    }
  }
}

/// Activity model - represents an activity in the user's feed
class ActivityModel {
  final String id;
  final ActivityType type;
  final String userId;           // Who performed the action
  final String? targetUserId;    // Who the action affects (optional)
  final String? groupId;         // Related group (optional)
  final String? expenseId;       // Related expense (optional)
  final String? settlementId;    // Related settlement (optional)
  final double? amount;          // Amount involved (optional)
  final String description;      // Human-readable description
  final Map<String, dynamic> metadata; // Extra data for flexibility
  final DateTime createdAt;
  final bool isRead;

  ActivityModel({
    required this.id,
    required this.type,
    required this.userId,
    this.targetUserId,
    this.groupId,
    this.expenseId,
    this.settlementId,
    this.amount,
    required this.description,
    this.metadata = const {},
    required this.createdAt,
    this.isRead = false,
  });

  /// Create from Firestore document
  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      id: doc.id,
      type: ActivityType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'expenseAdded'),
        orElse: () => ActivityType.expenseAdded,
      ),
      userId: data['userId'] ?? '',
      targetUserId: data['targetUserId'],
      groupId: data['groupId'],
      expenseId: data['expenseId'],
      settlementId: data['settlementId'],
      amount: data['amount']?.toDouble(),
      description: data['description'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'userId': userId,
      'targetUserId': targetUserId,
      'groupId': groupId,
      'expenseId': expenseId,
      'settlementId': settlementId,
      'amount': amount,
      'description': description,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  /// Create a copy with updated fields
  ActivityModel copyWith({
    ActivityType? type,
    String? userId,
    String? targetUserId,
    String? groupId,
    String? expenseId,
    String? settlementId,
    double? amount,
    String? description,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return ActivityModel(
      id: id,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      targetUserId: targetUserId ?? this.targetUserId,
      groupId: groupId ?? this.groupId,
      expenseId: expenseId ?? this.expenseId,
      settlementId: settlementId ?? this.settlementId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Get icon for this activity
  IconData get icon => type.icon;

  /// Get color for this activity
  Color get color => type.color;

  /// Get formatted amount with currency
  String? get formattedAmount {
    if (amount == null) return null;
    final currencySymbol = metadata['currencySymbol'] ?? '\$';
    return '$currencySymbol${amount!.toStringAsFixed(2)}';
  }

  /// Get relative time string
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}w ago';
    }
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }

  /// Get date group for grouping activities
  String get dateGroup {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(activityDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This Week';
    if (diff < 30) return 'This Month';
    if (diff < 365) return 'Earlier This Year';
    return 'Older';
  }

  /// Get actor name from metadata
  String get actorName => metadata['actorName'] ?? 'Someone';

  /// Get group name from metadata
  String? get groupName => metadata['groupName'];

  /// Get target name from metadata
  String? get targetName => metadata['targetName'];
}
