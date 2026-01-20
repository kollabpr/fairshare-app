import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/recurring_expense_model.dart';
import '../models/expense_model.dart';
import '../models/split_model.dart';
import '../models/direct_expense_model.dart';
import '../models/group_model.dart';

/// Service for managing recurring expenses
class RecurringExpenseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RecurringExpenseModel> _recurringExpenses = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<RecurringExpenseModel> get recurringExpenses => _recurringExpenses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Create a new recurring expense
  Future<RecurringExpenseModel?> createRecurringExpense({
    String? groupId,
    String? friendId,
    required String description,
    required double amount,
    String currencyCode = 'USD',
    required RecurringFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    int? dayOfWeek,
    int? dayOfMonth,
    required String payerId,
    String? payerUserId,
    String? payerName,
    String? payerEmail,
    SplitType splitType = SplitType.equal,
    required List<RecurringParticipant> participants,
    String category = 'other',
    String? notes,
    required String createdBy,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();

      // Calculate initial nextDueDate
      DateTime nextDueDate = startDate;
      if (nextDueDate.isBefore(now)) {
        nextDueDate = _calculateInitialNextDueDate(
          frequency: frequency,
          startDate: startDate,
          dayOfWeek: dayOfWeek,
          dayOfMonth: dayOfMonth,
        );
      }

      // Determine storage path
      DocumentReference docRef;
      if (groupId != null && groupId.isNotEmpty) {
        // Group recurring expense
        docRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('recurringExpenses')
            .doc();
      } else {
        // Personal/friend recurring expense - store under user
        docRef = _firestore
            .collection('users')
            .doc(createdBy)
            .collection('recurringExpenses')
            .doc();
      }

      final recurringExpense = RecurringExpenseModel(
        id: docRef.id,
        groupId: groupId,
        friendId: friendId,
        description: description,
        amount: amount,
        currencyCode: currencyCode,
        frequency: frequency,
        startDate: startDate,
        endDate: endDate,
        nextDueDate: nextDueDate,
        dayOfWeek: dayOfWeek,
        dayOfMonth: dayOfMonth,
        payerId: payerId,
        payerUserId: payerUserId,
        payerName: payerName,
        payerEmail: payerEmail,
        splitType: splitType,
        participants: participants,
        category: category,
        notes: notes,
        isActive: true,
        createdBy: createdBy,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(recurringExpense.toFirestore());

      _isLoading = false;
      notifyListeners();
      return recurringExpense;
    } catch (e) {
      _error = 'Failed to create recurring expense: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint(_error);
      return null;
    }
  }

  /// Update an existing recurring expense
  Future<bool> updateRecurringExpense({
    required String id,
    String? groupId,
    String? userId,
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
    SplitType? splitType,
    List<RecurringParticipant>? participants,
    String? category,
    String? notes,
    bool? isActive,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(now),
      };

      if (description != null) updates['description'] = description;
      if (amount != null) updates['amount'] = amount;
      if (currencyCode != null) updates['currencyCode'] = currencyCode;
      if (frequency != null) updates['frequency'] = frequency.name;
      if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
      if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
      if (nextDueDate != null) updates['nextDueDate'] = Timestamp.fromDate(nextDueDate);
      if (dayOfWeek != null) updates['dayOfWeek'] = dayOfWeek;
      if (dayOfMonth != null) updates['dayOfMonth'] = dayOfMonth;
      if (payerId != null) updates['payerId'] = payerId;
      if (payerUserId != null) updates['payerUserId'] = payerUserId;
      if (splitType != null) updates['splitType'] = splitType.name;
      if (participants != null) {
        updates['participants'] = participants.map((p) => p.toMap()).toList();
      }
      if (category != null) updates['category'] = category;
      if (notes != null) updates['notes'] = notes;
      if (isActive != null) updates['isActive'] = isActive;

      // Determine storage path
      if (groupId != null && groupId.isNotEmpty) {
        await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('recurringExpenses')
            .doc(id)
            .update(updates);
      } else if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('recurringExpenses')
            .doc(id)
            .update(updates);
      } else {
        _error = 'Either groupId or userId must be provided';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update recurring expense: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint(_error);
      return false;
    }
  }

  /// Delete (soft delete) a recurring expense
  Future<bool> deleteRecurringExpense({
    required String id,
    String? groupId,
    String? userId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updates = <String, dynamic>{
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (groupId != null && groupId.isNotEmpty) {
        await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('recurringExpenses')
            .doc(id)
            .update(updates);
      } else if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('recurringExpenses')
            .doc(id)
            .update(updates);
      } else {
        _error = 'Either groupId or userId must be provided';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete recurring expense: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint(_error);
      return false;
    }
  }

  /// Pause a recurring expense
  Future<bool> pauseRecurringExpense({
    required String id,
    String? groupId,
    String? userId,
  }) async {
    return updateRecurringExpense(
      id: id,
      groupId: groupId,
      userId: userId,
      isActive: false,
    );
  }

  /// Resume a paused recurring expense
  Future<bool> resumeRecurringExpense({
    required String id,
    String? groupId,
    String? userId,
  }) async {
    return updateRecurringExpense(
      id: id,
      groupId: groupId,
      userId: userId,
      isActive: true,
    );
  }

  // ============================================
  // STREAM METHODS
  // ============================================

  /// Stream all recurring expenses for a user (both personal and from groups)
  Stream<List<RecurringExpenseModel>> streamRecurringExpenses(String userId) {
    // Stream personal recurring expenses
    final personalStream = _firestore
        .collection('users')
        .doc(userId)
        .collection('recurringExpenses')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RecurringExpenseModel.fromFirestore(doc))
            .toList());

    return personalStream.map((expenses) {
      _recurringExpenses = expenses;
      _recurringExpenses.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      notifyListeners();
      return _recurringExpenses;
    });
  }

  /// Stream recurring expenses for a specific group
  Stream<List<RecurringExpenseModel>> streamRecurringExpensesByGroup(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('recurringExpenses')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final expenses = snapshot.docs
              .map((doc) => RecurringExpenseModel.fromFirestore(doc))
              .toList();
          expenses.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
          return expenses;
        });
  }

  /// Get upcoming recurring expenses due within N days
  Future<List<RecurringExpenseModel>> getUpcomingExpenses(
    String userId,
    int days,
  ) async {
    try {
      final now = DateTime.now();
      final cutoffDate = now.add(Duration(days: days));

      // Get personal recurring expenses
      final personalSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recurringExpenses')
          .where('isActive', isEqualTo: true)
          .where('nextDueDate', isLessThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .get();

      final expenses = personalSnapshot.docs
          .map((doc) => RecurringExpenseModel.fromFirestore(doc))
          .toList();

      expenses.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      return expenses;
    } catch (e) {
      debugPrint('Error getting upcoming expenses: $e');
      return [];
    }
  }

  // ============================================
  // EXPENSE GENERATION
  // ============================================

  /// Generate actual expense records for any recurring expenses that are due
  Future<int> generateDueExpenses(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int generatedCount = 0;

      // Get all active recurring expenses that are due
      final personalSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recurringExpenses')
          .where('isActive', isEqualTo: true)
          .where('nextDueDate', isLessThanOrEqualTo: Timestamp.fromDate(today))
          .get();

      for (final doc in personalSnapshot.docs) {
        final recurringExpense = RecurringExpenseModel.fromFirestore(doc);

        // Check if end date has passed
        if (recurringExpense.endDate != null &&
            recurringExpense.endDate!.isBefore(today)) {
          // Deactivate the recurring expense
          await doc.reference.update({
            'isActive': false,
            'updatedAt': Timestamp.fromDate(now),
          });
          continue;
        }

        // Generate the expense
        final generated = await _generateExpenseFromRecurring(recurringExpense, userId);

        if (generated) {
          // Calculate and update next due date
          final nextDueDate = recurringExpense.calculateNextDueDate();

          await doc.reference.update({
            'lastGeneratedAt': Timestamp.fromDate(now),
            'nextDueDate': Timestamp.fromDate(nextDueDate),
            'updatedAt': Timestamp.fromDate(now),
          });

          generatedCount++;
        }
      }

      _isLoading = false;
      notifyListeners();
      return generatedCount;
    } catch (e) {
      _error = 'Failed to generate expenses: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint(_error);
      return 0;
    }
  }

  /// Generate a single expense from a recurring expense template
  Future<bool> _generateExpenseFromRecurring(
    RecurringExpenseModel recurring,
    String userId,
  ) async {
    try {
      final now = DateTime.now();

      if (recurring.isGroupExpense && recurring.groupId != null) {
        // Create group expense
        final expenseRef = _firestore
            .collection('groups')
            .doc(recurring.groupId)
            .collection('expenses')
            .doc();

        final batch = _firestore.batch();

        // Create expense
        batch.set(expenseRef, {
          'groupId': recurring.groupId,
          'description': recurring.description,
          'amount': recurring.amount,
          'currencyCode': recurring.currencyCode,
          'payerId': recurring.payerId,
          'payerUserId': recurring.payerUserId,
          'date': Timestamp.fromDate(recurring.nextDueDate),
          'category': recurring.category,
          'notes': recurring.notes != null
              ? '${recurring.notes} (Auto-generated from recurring expense)'
              : 'Auto-generated from recurring expense',
          'splitType': recurring.splitType.name,
          'createdBy': userId,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'isDeleted': false,
          'recurringExpenseId': recurring.id,
        });

        // Create splits for each participant
        for (final participant in recurring.participants) {
          final splitRef = expenseRef.collection('splits').doc();

          // Calculate paid amount (only payer pays)
          final paidAmount = participant.memberId == recurring.payerId
              ? recurring.amount
              : 0.0;

          batch.set(splitRef, {
            'id': splitRef.id,
            'expenseId': expenseRef.id,
            'memberId': participant.memberId,
            'userId': participant.userId,
            'owedAmount': participant.amount,
            'paidAmount': paidAmount,
            'percentage': participant.percentage,
            'shares': participant.shares,
            'isSettled': false,
          });

          // Update member balance
          final netAmount = participant.amount - paidAmount;
          final memberRef = _firestore
              .collection('groups')
              .doc(recurring.groupId)
              .collection('members')
              .doc(participant.memberId);

          batch.update(memberRef, {
            'balance': FieldValue.increment(-netAmount),
          });
        }

        // Update group total expenses
        batch.update(_firestore.collection('groups').doc(recurring.groupId), {
          'totalExpenses': FieldValue.increment(recurring.amount),
          'updatedAt': Timestamp.now(),
        });

        await batch.commit();
        return true;
      } else if (recurring.isFriendExpense && recurring.friendId != null) {
        // Create direct expense between friends
        final expenseRef = _firestore.collection('directExpenses').doc();

        // For direct expenses, we need payer and participant info
        final participant = recurring.participants.firstWhere(
          (p) => p.userId != recurring.payerUserId,
          orElse: () => recurring.participants.first,
        );

        await expenseRef.set({
          'description': recurring.description,
          'amount': recurring.amount,
          'currencyCode': recurring.currencyCode,
          'payerId': recurring.payerUserId ?? recurring.payerId,
          'payerEmail': recurring.payerEmail ?? '',
          'payerName': recurring.payerName,
          'participantId': participant.userId ?? participant.memberId,
          'participantEmail': participant.email ?? '',
          'participantName': participant.name,
          'participants': [
            recurring.payerUserId ?? recurring.payerId,
            participant.userId ?? participant.memberId,
          ],
          'date': Timestamp.fromDate(recurring.nextDueDate),
          'category': recurring.category,
          'notes': recurring.notes != null
              ? '${recurring.notes} (Auto-generated from recurring expense)'
              : 'Auto-generated from recurring expense',
          'splitType': recurring.splitType.name,
          'payerOwedAmount': 0.0,
          'participantOwedAmount': participant.amount,
          'createdBy': userId,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'isDeleted': false,
          'isSettled': false,
          'recurringExpenseId': recurring.id,
        });

        // Update friend balances
        final payerFriendQuery = await _firestore
            .collection('users')
            .doc(recurring.payerUserId ?? recurring.payerId)
            .collection('friends')
            .where('friendUserId', isEqualTo: participant.userId ?? participant.memberId)
            .limit(1)
            .get();

        if (payerFriendQuery.docs.isNotEmpty) {
          await payerFriendQuery.docs.first.reference.update({
            'totalBalance': FieldValue.increment(participant.amount),
            'updatedAt': Timestamp.fromDate(now),
          });
        }

        final participantFriendQuery = await _firestore
            .collection('users')
            .doc(participant.userId ?? participant.memberId)
            .collection('friends')
            .where('friendUserId', isEqualTo: recurring.payerUserId ?? recurring.payerId)
            .limit(1)
            .get();

        if (participantFriendQuery.docs.isNotEmpty) {
          await participantFriendQuery.docs.first.reference.update({
            'totalBalance': FieldValue.increment(-participant.amount),
            'updatedAt': Timestamp.fromDate(now),
          });
        }

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error generating expense from recurring: $e');
      return false;
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Calculate the initial next due date based on frequency and start date
  DateTime _calculateInitialNextDueDate({
    required RecurringFrequency frequency,
    required DateTime startDate,
    int? dayOfWeek,
    int? dayOfMonth,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (frequency) {
      case RecurringFrequency.daily:
        return today;

      case RecurringFrequency.weekly:
        // Find the next occurrence of the specified day of week
        if (dayOfWeek != null) {
          var nextDate = today;
          while (nextDate.weekday != dayOfWeek) {
            nextDate = nextDate.add(const Duration(days: 1));
          }
          return nextDate;
        }
        return today;

      case RecurringFrequency.biweekly:
        // Find the next occurrence of the specified day of week
        if (dayOfWeek != null) {
          var nextDate = today;
          while (nextDate.weekday != dayOfWeek) {
            nextDate = nextDate.add(const Duration(days: 1));
          }
          // If we're past the original start date cycle, align to it
          final weeksSinceStart = nextDate.difference(startDate).inDays ~/ 7;
          if (weeksSinceStart.isOdd) {
            nextDate = nextDate.add(const Duration(days: 7));
          }
          return nextDate;
        }
        return today;

      case RecurringFrequency.monthly:
        if (dayOfMonth != null) {
          var nextDate = DateTime(today.year, today.month, dayOfMonth);
          if (nextDate.isBefore(today) || nextDate.isAtSameMomentAs(today)) {
            nextDate = DateTime(today.year, today.month + 1, dayOfMonth);
          }
          // Handle invalid dates (e.g., Feb 30)
          while (nextDate.day != dayOfMonth) {
            nextDate = nextDate.subtract(const Duration(days: 1));
          }
          return nextDate;
        }
        return DateTime(today.year, today.month + 1, startDate.day);

      case RecurringFrequency.yearly:
        var nextDate = DateTime(today.year, startDate.month, startDate.day);
        if (nextDate.isBefore(today)) {
          nextDate = DateTime(today.year + 1, startDate.month, startDate.day);
        }
        return nextDate;
    }
  }

  /// Get a single recurring expense by ID
  Future<RecurringExpenseModel?> getRecurringExpense({
    required String id,
    String? groupId,
    String? userId,
  }) async {
    try {
      DocumentSnapshot doc;

      if (groupId != null && groupId.isNotEmpty) {
        doc = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('recurringExpenses')
            .doc(id)
            .get();
      } else if (userId != null) {
        doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('recurringExpenses')
            .doc(id)
            .get();
      } else {
        return null;
      }

      if (doc.exists) {
        return RecurringExpenseModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting recurring expense: $e');
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
