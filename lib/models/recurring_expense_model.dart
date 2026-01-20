import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'expense_model.dart';
import 'group_model.dart';

/// Frequency options for recurring expenses
enum RecurringFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  yearly,
}

/// Participant in a recurring expense with their split amount
class RecurringParticipant {
  final String memberId;
  final String? userId;
  final String? name;
  final String? email;
  final double amount;
  final double? percentage;
  final int? shares;

  RecurringParticipant({
    required this.memberId,
    this.userId,
    this.name,
    this.email,
    required this.amount,
    this.percentage,
    this.shares,
  });

  factory RecurringParticipant.fromMap(Map<String, dynamic> map) {
    return RecurringParticipant(
      memberId: map['memberId'] ?? '',
      userId: map['userId'],
      name: map['name'],
      email: map['email'],
      amount: (map['amount'] ?? 0).toDouble(),
      percentage: map['percentage']?.toDouble(),
      shares: map['shares'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'userId': userId,
      'name': name,
      'email': email,
      'amount': amount,
      'percentage': percentage,
      'shares': shares,
    };
  }

  RecurringParticipant copyWith({
    String? memberId,
    String? userId,
    String? name,
    String? email,
    double? amount,
    double? percentage,
    int? shares,
  }) {
    return RecurringParticipant(
      memberId: memberId ?? this.memberId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
    );
  }
}

/// Recurring expense model - represents an expense that repeats automatically
class RecurringExpenseModel {
  final String id;
  final String? groupId;           // Optional - for group expenses
  final String? friendId;          // Optional - for direct friend expenses
  final String description;
  final double amount;
  final String currencyCode;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;         // Optional end date
  final DateTime nextDueDate;
  final int? dayOfWeek;            // 1-7 for weekly frequency (1=Monday)
  final int? dayOfMonth;           // 1-31 for monthly frequency
  final String payerId;
  final String? payerUserId;
  final String? payerName;
  final String? payerEmail;
  final SplitType splitType;
  final List<RecurringParticipant> participants;
  final String category;
  final String? notes;
  final bool isActive;
  final DateTime? lastGeneratedAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecurringExpenseModel({
    required this.id,
    this.groupId,
    this.friendId,
    required this.description,
    required this.amount,
    this.currencyCode = 'USD',
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.nextDueDate,
    this.dayOfWeek,
    this.dayOfMonth,
    required this.payerId,
    this.payerUserId,
    this.payerName,
    this.payerEmail,
    this.splitType = SplitType.equal,
    required this.participants,
    this.category = 'other',
    this.notes,
    this.isActive = true,
    this.lastGeneratedAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory RecurringExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringExpenseModel(
      id: doc.id,
      groupId: data['groupId'],
      friendId: data['friendId'],
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currencyCode: data['currencyCode'] ?? 'USD',
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == (data['frequency'] ?? 'monthly'),
        orElse: () => RecurringFrequency.monthly,
      ),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      nextDueDate: (data['nextDueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dayOfWeek: data['dayOfWeek'],
      dayOfMonth: data['dayOfMonth'],
      payerId: data['payerId'] ?? '',
      payerUserId: data['payerUserId'],
      payerName: data['payerName'],
      payerEmail: data['payerEmail'],
      splitType: SplitType.values.firstWhere(
        (e) => e.name == (data['splitType'] ?? 'equal'),
        orElse: () => SplitType.equal,
      ),
      participants: (data['participants'] as List<dynamic>?)
              ?.map((p) => RecurringParticipant.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      category: data['category'] ?? 'other',
      notes: data['notes'],
      isActive: data['isActive'] ?? true,
      lastGeneratedAt: (data['lastGeneratedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'friendId': friendId,
      'description': description,
      'amount': amount,
      'currencyCode': currencyCode,
      'frequency': frequency.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'nextDueDate': Timestamp.fromDate(nextDueDate),
      'dayOfWeek': dayOfWeek,
      'dayOfMonth': dayOfMonth,
      'payerId': payerId,
      'payerUserId': payerUserId,
      'payerName': payerName,
      'payerEmail': payerEmail,
      'splitType': splitType.name,
      'participants': participants.map((p) => p.toMap()).toList(),
      'category': category,
      'notes': notes,
      'isActive': isActive,
      'lastGeneratedAt': lastGeneratedAt != null
          ? Timestamp.fromDate(lastGeneratedAt!)
          : null,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  RecurringExpenseModel copyWith({
    String? groupId,
    String? friendId,
    String? description,
    double? amount,
    String? currencyCode,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextDueDate,
    int? dayOfWeek,
    int? dayOfMonth,
    String? payerId,
    String? payerUserId,
    String? payerName,
    String? payerEmail,
    SplitType? splitType,
    List<RecurringParticipant>? participants,
    String? category,
    String? notes,
    bool? isActive,
    DateTime? lastGeneratedAt,
    DateTime? updatedAt,
  }) {
    return RecurringExpenseModel(
      id: id,
      groupId: groupId ?? this.groupId,
      friendId: friendId ?? this.friendId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      payerId: payerId ?? this.payerId,
      payerUserId: payerUserId ?? this.payerUserId,
      payerName: payerName ?? this.payerName,
      payerEmail: payerEmail ?? this.payerEmail,
      splitType: splitType ?? this.splitType,
      participants: participants ?? this.participants,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      lastGeneratedAt: lastGeneratedAt ?? this.lastGeneratedAt,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Check if the expense is overdue
  bool get isOverdue {
    if (!isActive) return false;
    final now = DateTime.now();
    return nextDueDate.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Calculate days until due (negative if overdue)
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return dueDay.difference(today).inDays;
  }

  /// Get display name for frequency
  String get frequencyDisplayName {
    switch (frequency) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.biweekly:
        return 'Every 2 weeks';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  /// Get detailed frequency description
  String get frequencyDescription {
    switch (frequency) {
      case RecurringFrequency.daily:
        return 'Every day';
      case RecurringFrequency.weekly:
        if (dayOfWeek != null) {
          return 'Every ${_dayOfWeekName(dayOfWeek!)}';
        }
        return 'Weekly';
      case RecurringFrequency.biweekly:
        if (dayOfWeek != null) {
          return 'Every other ${_dayOfWeekName(dayOfWeek!)}';
        }
        return 'Every 2 weeks';
      case RecurringFrequency.monthly:
        if (dayOfMonth != null) {
          return 'Monthly on the ${_ordinal(dayOfMonth!)}';
        }
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  /// Get icon for frequency
  IconData get frequencyIcon {
    switch (frequency) {
      case RecurringFrequency.daily:
        return Icons.today_rounded;
      case RecurringFrequency.weekly:
        return Icons.view_week_rounded;
      case RecurringFrequency.biweekly:
        return Icons.date_range_rounded;
      case RecurringFrequency.monthly:
        return Icons.calendar_month_rounded;
      case RecurringFrequency.yearly:
        return Icons.event_rounded;
    }
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

  /// Get due date status text
  String get dueStatusText {
    if (!isActive) return 'Paused';
    if (isOverdue) {
      final days = -daysUntilDue;
      if (days == 1) return 'Overdue by 1 day';
      return 'Overdue by $days days';
    }
    if (daysUntilDue == 0) return 'Due today';
    if (daysUntilDue == 1) return 'Due tomorrow';
    if (daysUntilDue <= 7) return 'Due in $daysUntilDue days';
    return 'Due ${_formatDate(nextDueDate)}';
  }

  /// Check if this is a group expense
  bool get isGroupExpense => groupId != null && groupId!.isNotEmpty;

  /// Check if this is a friend/direct expense
  bool get isFriendExpense => friendId != null && friendId!.isNotEmpty;

  /// Calculate the next due date after generating an expense
  DateTime calculateNextDueDate() {
    switch (frequency) {
      case RecurringFrequency.daily:
        return nextDueDate.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return nextDueDate.add(const Duration(days: 7));
      case RecurringFrequency.biweekly:
        return nextDueDate.add(const Duration(days: 14));
      case RecurringFrequency.monthly:
        // Handle month rollover properly
        var next = DateTime(
          nextDueDate.year,
          nextDueDate.month + 1,
          dayOfMonth ?? nextDueDate.day,
        );
        // Handle cases where day doesn't exist in month (e.g., 31st)
        while (next.month > (nextDueDate.month + 1) % 12) {
          next = next.subtract(const Duration(days: 1));
        }
        return next;
      case RecurringFrequency.yearly:
        return DateTime(
          nextDueDate.year + 1,
          nextDueDate.month,
          nextDueDate.day,
        );
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  String _dayOfWeekName(int day) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[(day - 1).clamp(0, 6)];
  }

  String _ordinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
