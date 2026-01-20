import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/expense_model.dart';
import '../models/direct_expense_model.dart';
import '../models/group_model.dart';

/// Time period options for reports
enum TimePeriod {
  thisMonth,
  lastMonth,
  thisYear,
  allTime,
}

/// Granularity for time series data
enum TimeGranularity {
  daily,
  weekly,
  monthly,
}

/// Spending summary data
class SpendingSummary {
  final double totalSpent;
  final double averagePerDay;
  final double previousPeriodTotal;
  final double percentChange;
  final int transactionCount;

  SpendingSummary({
    required this.totalSpent,
    required this.averagePerDay,
    required this.previousPeriodTotal,
    required this.percentChange,
    required this.transactionCount,
  });

  bool get isIncrease => percentChange > 0;
  bool get isDecrease => percentChange < 0;
  bool get isUnchanged => percentChange.abs() < 0.01;
}

/// Time series data point
class TimeSeriesDataPoint {
  final DateTime date;
  final double amount;
  final String label;

  TimeSeriesDataPoint({
    required this.date,
    required this.amount,
    required this.label,
  });
}

/// Category spending data
class CategorySpending {
  final String category;
  final double amount;
  final int count;
  final double percentage;

  CategorySpending({
    required this.category,
    required this.amount,
    required this.count,
    required this.percentage,
  });
}

/// Group/Friend spending data
class GroupSpending {
  final String id;
  final String name;
  final double amount;
  final int count;

  GroupSpending({
    required this.id,
    required this.name,
    required this.amount,
    required this.count,
  });
}

/// Top expense item
class TopExpenseItem {
  final String id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String? groupName;

  TopExpenseItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.groupName,
  });
}

/// Service for generating reports and analytics
class ReportsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get date range for a time period
  ({DateTime start, DateTime end}) getDateRange(TimePeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case TimePeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (start: start, end: end);

      case TimePeriod.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0, 23, 59, 59);
        return (start: start, end: end);

      case TimePeriod.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59);
        return (start: start, end: end);

      case TimePeriod.allTime:
        // Use a very old date as start
        final start = DateTime(2000, 1, 1);
        final end = today.add(const Duration(days: 1));
        return (start: start, end: end);
    }
  }

  /// Get previous period date range for comparison
  ({DateTime start, DateTime end}) getPreviousPeriodRange(TimePeriod period) {
    final currentRange = getDateRange(period);

    switch (period) {
      case TimePeriod.thisMonth:
        final prevStart = DateTime(
          currentRange.start.year,
          currentRange.start.month - 1,
          1,
        );
        final prevEnd = DateTime(
          currentRange.start.year,
          currentRange.start.month,
          0,
          23,
          59,
          59,
        );
        return (start: prevStart, end: prevEnd);

      case TimePeriod.lastMonth:
        final prevStart = DateTime(
          currentRange.start.year,
          currentRange.start.month - 1,
          1,
        );
        final prevEnd = DateTime(
          currentRange.start.year,
          currentRange.start.month,
          0,
          23,
          59,
          59,
        );
        return (start: prevStart, end: prevEnd);

      case TimePeriod.thisYear:
        final prevStart = DateTime(currentRange.start.year - 1, 1, 1);
        final prevEnd = DateTime(currentRange.start.year - 1, 12, 31, 23, 59, 59);
        return (start: prevStart, end: prevEnd);

      case TimePeriod.allTime:
        // No comparison for all time
        return (start: DateTime(2000, 1, 1), end: DateTime(2000, 1, 1));
    }
  }

  /// Get all expenses for a user (from groups and direct expenses)
  Future<List<ExpenseModel>> _getGroupExpenses(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final List<ExpenseModel> allExpenses = [];

    try {
      // Get all groups the user is a member of
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('memberIds', arrayContains: userId)
          .get();

      // Fetch expenses from each group
      for (final groupDoc in groupsSnapshot.docs) {
        final expensesSnapshot = await _firestore
            .collection('groups')
            .doc(groupDoc.id)
            .collection('expenses')
            .get();

        for (final expenseDoc in expensesSnapshot.docs) {
          final expense = ExpenseModel.fromFirestore(expenseDoc);

          // Filter by date range and not deleted
          if (!expense.isDeleted &&
              !expense.isSettlement &&
              expense.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
              expense.date.isBefore(endDate.add(const Duration(seconds: 1)))) {
            allExpenses.add(expense);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching group expenses: $e');
    }

    return allExpenses;
  }

  /// Get direct expenses for a user
  Future<List<DirectExpenseModel>> _getDirectExpenses(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final List<DirectExpenseModel> expenses = [];

    try {
      final snapshot = await _firestore
          .collection('directExpenses')
          .where('participants', arrayContains: userId)
          .get();

      for (final doc in snapshot.docs) {
        final expense = DirectExpenseModel.fromFirestore(doc);

        if (!expense.isDeleted &&
            expense.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            expense.date.isBefore(endDate.add(const Duration(seconds: 1)))) {
          expenses.add(expense);
        }
      }
    } catch (e) {
      debugPrint('Error fetching direct expenses: $e');
    }

    return expenses;
  }

  /// Get spending by category
  Future<Map<String, CategorySpending>> getSpendingByCategory(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _isLoading = true;
    notifyListeners();

    final Map<String, double> categoryAmounts = {};
    final Map<String, int> categoryCounts = {};

    try {
      // Get group expenses
      final groupExpenses = await _getGroupExpenses(userId, startDate, endDate);
      for (final expense in groupExpenses) {
        final category = expense.category;
        categoryAmounts[category] = (categoryAmounts[category] ?? 0) + expense.amount;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      // Get direct expenses
      final directExpenses = await _getDirectExpenses(userId, startDate, endDate);
      for (final expense in directExpenses) {
        final category = expense.category;
        categoryAmounts[category] = (categoryAmounts[category] ?? 0) + expense.amount;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      // Calculate total for percentages
      final total = categoryAmounts.values.fold<double>(0, (sum, amount) => sum + amount);

      // Build result map with percentages
      final result = <String, CategorySpending>{};
      for (final entry in categoryAmounts.entries) {
        result[entry.key] = CategorySpending(
          category: entry.key,
          amount: entry.value,
          count: categoryCounts[entry.key] ?? 0,
          percentage: total > 0 ? (entry.value / total) * 100 : 0,
        );
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = 'Failed to get spending by category: $e';
      _isLoading = false;
      notifyListeners();
      return {};
    }
  }

  /// Get spending by group
  Future<Map<String, GroupSpending>> getSpendingByGroup(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _isLoading = true;
    notifyListeners();

    final Map<String, GroupSpending> result = {};

    try {
      // Get all groups the user is a member of
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('memberIds', arrayContains: userId)
          .get();

      for (final groupDoc in groupsSnapshot.docs) {
        final group = GroupModel.fromFirestore(groupDoc);
        double totalAmount = 0;
        int count = 0;

        final expensesSnapshot = await _firestore
            .collection('groups')
            .doc(groupDoc.id)
            .collection('expenses')
            .get();

        for (final expenseDoc in expensesSnapshot.docs) {
          final expense = ExpenseModel.fromFirestore(expenseDoc);

          if (!expense.isDeleted &&
              !expense.isSettlement &&
              expense.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
              expense.date.isBefore(endDate.add(const Duration(seconds: 1)))) {
            totalAmount += expense.amount;
            count++;
          }
        }

        if (count > 0) {
          result[group.id] = GroupSpending(
            id: group.id,
            name: group.name,
            amount: totalAmount,
            count: count,
          );
        }
      }

      // Add direct expenses as "Direct Expenses" group
      final directExpenses = await _getDirectExpenses(userId, startDate, endDate);
      if (directExpenses.isNotEmpty) {
        final directTotal = directExpenses.fold<double>(0, (sum, e) => sum + e.amount);
        result['direct'] = GroupSpending(
          id: 'direct',
          name: 'Direct Expenses',
          amount: directTotal,
          count: directExpenses.length,
        );
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = 'Failed to get spending by group: $e';
      _isLoading = false;
      notifyListeners();
      return {};
    }
  }

  /// Get spending over time
  Future<List<TimeSeriesDataPoint>> getSpendingOverTime(
    String userId,
    DateTime startDate,
    DateTime endDate,
    TimeGranularity granularity,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get all expenses
      final groupExpenses = await _getGroupExpenses(userId, startDate, endDate);
      final directExpenses = await _getDirectExpenses(userId, startDate, endDate);

      // Combine and sort by date
      final allExpenses = <({DateTime date, double amount})>[];

      for (final expense in groupExpenses) {
        allExpenses.add((date: expense.date, amount: expense.amount));
      }
      for (final expense in directExpenses) {
        allExpenses.add((date: expense.date, amount: expense.amount));
      }

      allExpenses.sort((a, b) => a.date.compareTo(b.date));

      // Group by time period
      final Map<String, double> groupedData = {};

      for (final expense in allExpenses) {
        final key = _getTimeKey(expense.date, granularity);
        groupedData[key] = (groupedData[key] ?? 0) + expense.amount;
      }

      // Fill in missing periods with zero
      final filledData = _fillMissingPeriods(
        groupedData,
        startDate,
        endDate,
        granularity,
      );

      _isLoading = false;
      notifyListeners();
      return filledData;
    } catch (e) {
      _error = 'Failed to get spending over time: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  String _getTimeKey(DateTime date, TimeGranularity granularity) {
    switch (granularity) {
      case TimeGranularity.daily:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case TimeGranularity.weekly:
        // Get the start of the week (Monday)
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        return '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
      case TimeGranularity.monthly:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
  }

  String _getTimeLabel(DateTime date, TimeGranularity granularity) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    switch (granularity) {
      case TimeGranularity.daily:
        return '${months[date.month - 1]} ${date.day}';
      case TimeGranularity.weekly:
        return '${months[date.month - 1]} ${date.day}';
      case TimeGranularity.monthly:
        return months[date.month - 1];
    }
  }

  List<TimeSeriesDataPoint> _fillMissingPeriods(
    Map<String, double> data,
    DateTime startDate,
    DateTime endDate,
    TimeGranularity granularity,
  ) {
    final result = <TimeSeriesDataPoint>[];
    var current = startDate;

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      final key = _getTimeKey(current, granularity);
      final amount = data[key] ?? 0;
      final label = _getTimeLabel(current, granularity);

      result.add(TimeSeriesDataPoint(
        date: current,
        amount: amount,
        label: label,
      ));

      // Move to next period
      switch (granularity) {
        case TimeGranularity.daily:
          current = current.add(const Duration(days: 1));
          break;
        case TimeGranularity.weekly:
          current = current.add(const Duration(days: 7));
          break;
        case TimeGranularity.monthly:
          current = DateTime(current.year, current.month + 1, 1);
          break;
      }
    }

    return result;
  }

  /// Get top expenses
  Future<List<TopExpenseItem>> getTopExpenses(
    String userId,
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final start = startDate ?? DateTime(2000, 1, 1);
      final end = endDate ?? DateTime.now().add(const Duration(days: 1));

      // Get all expenses
      final groupExpenses = await _getGroupExpenses(userId, start, end);
      final directExpenses = await _getDirectExpenses(userId, start, end);

      // Combine and sort by amount
      final allExpenses = <TopExpenseItem>[];

      // Get group names for group expenses
      final groupNames = <String, String>{};
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('memberIds', arrayContains: userId)
          .get();

      for (final doc in groupsSnapshot.docs) {
        final group = GroupModel.fromFirestore(doc);
        groupNames[group.id] = group.name;
      }

      for (final expense in groupExpenses) {
        allExpenses.add(TopExpenseItem(
          id: expense.id,
          description: expense.description,
          amount: expense.amount,
          category: expense.category,
          date: expense.date,
          groupName: groupNames[expense.groupId],
        ));
      }

      for (final expense in directExpenses) {
        allExpenses.add(TopExpenseItem(
          id: expense.id,
          description: expense.description,
          amount: expense.amount,
          category: expense.category,
          date: expense.date,
          groupName: null,
        ));
      }

      // Sort by amount descending
      allExpenses.sort((a, b) => b.amount.compareTo(a.amount));

      _isLoading = false;
      notifyListeners();
      return allExpenses.take(limit).toList();
    } catch (e) {
      _error = 'Failed to get top expenses: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Get spending summary with comparison to previous period
  Future<SpendingSummary> getSpendingSummary(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get current period expenses
      final groupExpenses = await _getGroupExpenses(userId, startDate, endDate);
      final directExpenses = await _getDirectExpenses(userId, startDate, endDate);

      final totalSpent = groupExpenses.fold<double>(0, (sum, e) => sum + e.amount) +
          directExpenses.fold<double>(0, (sum, e) => sum + e.amount);

      final transactionCount = groupExpenses.length + directExpenses.length;

      // Calculate days in period
      final daysInPeriod = endDate.difference(startDate).inDays + 1;
      final averagePerDay = daysInPeriod > 0 ? totalSpent / daysInPeriod : 0.0;

      // Get previous period for comparison
      final periodDuration = endDate.difference(startDate);
      final prevEnd = startDate.subtract(const Duration(days: 1));
      final prevStart = prevEnd.subtract(periodDuration);

      final prevGroupExpenses = await _getGroupExpenses(userId, prevStart, prevEnd);
      final prevDirectExpenses = await _getDirectExpenses(userId, prevStart, prevEnd);

      final previousPeriodTotal = prevGroupExpenses.fold<double>(0, (sum, e) => sum + e.amount) +
          prevDirectExpenses.fold<double>(0, (sum, e) => sum + e.amount);

      // Calculate percent change
      double percentChange = 0;
      if (previousPeriodTotal > 0) {
        percentChange = ((totalSpent - previousPeriodTotal) / previousPeriodTotal) * 100;
      } else if (totalSpent > 0) {
        percentChange = 100; // 100% increase from 0
      }

      _isLoading = false;
      notifyListeners();

      return SpendingSummary(
        totalSpent: totalSpent,
        averagePerDay: averagePerDay,
        previousPeriodTotal: previousPeriodTotal,
        percentChange: percentChange,
        transactionCount: transactionCount,
      );
    } catch (e) {
      _error = 'Failed to get spending summary: $e';
      _isLoading = false;
      notifyListeners();
      return SpendingSummary(
        totalSpent: 0.0,
        averagePerDay: 0.0,
        previousPeriodTotal: 0.0,
        percentChange: 0.0,
        transactionCount: 0,
      );
    }
  }

  /// Export data as CSV string
  Future<String> exportToCSV(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln('Date,Description,Category,Amount,Group/Friend,Type');

    try {
      // Get group expenses
      final groupExpenses = await _getGroupExpenses(userId, startDate, endDate);

      // Get group names
      final groupNames = <String, String>{};
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('memberIds', arrayContains: userId)
          .get();

      for (final doc in groupsSnapshot.docs) {
        final group = GroupModel.fromFirestore(doc);
        groupNames[group.id] = group.name;
      }

      for (final expense in groupExpenses) {
        final date = '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}-${expense.date.day.toString().padLeft(2, '0')}';
        final description = expense.description.replaceAll(',', ';');
        final groupName = groupNames[expense.groupId] ?? 'Unknown';
        buffer.writeln('$date,"$description",${expense.category},${expense.amount.toStringAsFixed(2)},"$groupName",Group');
      }

      // Get direct expenses
      final directExpenses = await _getDirectExpenses(userId, startDate, endDate);

      for (final expense in directExpenses) {
        final date = '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}-${expense.date.day.toString().padLeft(2, '0')}';
        final description = expense.description.replaceAll(',', ';');
        final friendName = expense.payerId == userId
            ? (expense.participantName ?? expense.participantEmail)
            : (expense.payerName ?? expense.payerEmail);
        buffer.writeln('$date,"$description",${expense.category},${expense.amount.toStringAsFixed(2)},"$friendName",Direct');
      }
    } catch (e) {
      debugPrint('Error exporting data: $e');
    }

    return buffer.toString();
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
