import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/expense_model.dart';
import '../models/split_model.dart';
import '../models/settlement_model.dart';
import '../models/group_model.dart';

/// Service for managing shared expenses
class ExpensesService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ExpenseModel> _expenses = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ExpenseModel> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Stream expenses for a group
  Stream<List<ExpenseModel>> streamExpenses(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .where('isDeleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          _expenses = snapshot.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .toList();
          notifyListeners();
          return _expenses;
        });
  }

  /// Get a single expense by ID
  Future<ExpenseModel?> getExpense(String groupId, String expenseId) async {
    try {
      final doc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .get();

      if (doc.exists) {
        return ExpenseModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting expense: $e');
      return null;
    }
  }

  /// Create a new expense with splits
  Future<ExpenseModel?> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String payerId,
    required String createdBy,
    required List<SplitModel> splits,
    String currencyCode = 'USD',
    String? payerUserId,
    DateTime? date,
    String category = 'other',
    String? notes,
    String? receiptImageUrl,
    SplitType splitType = SplitType.equal,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final expenseRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc();

      final expense = ExpenseModel(
        id: expenseRef.id,
        groupId: groupId,
        description: description,
        amount: amount,
        currencyCode: currencyCode,
        payerId: payerId,
        payerUserId: payerUserId,
        date: date ?? now,
        category: category,
        notes: notes,
        receiptImageUrl: receiptImageUrl,
        splitType: splitType,
        createdBy: createdBy,
        createdAt: now,
        updatedAt: now,
      );

      // Use batch write for atomicity
      final batch = _firestore.batch();

      // Create expense
      batch.set(expenseRef, expense.toFirestore());

      // Create splits and update member balances
      for (final split in splits) {
        final splitRef = expenseRef.collection('splits').doc();
        batch.set(splitRef, {
          ...split.toFirestore(),
          'id': splitRef.id,
          'expenseId': expense.id,
        });

        // Update member balance
        // Net amount: positive = owes more, negative = gets back
        final netAmount = split.owedAmount - split.paidAmount;
        final memberRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(split.memberId);

        batch.update(memberRef, {
          'balance': FieldValue.increment(-netAmount), // negative = owes, positive = gets back
        });
      }

      // Update group total expenses
      final groupRef = _firestore.collection('groups').doc(groupId);
      batch.update(groupRef, {
        'totalExpenses': FieldValue.increment(amount),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return expense;
    } catch (e) {
      _error = 'Failed to create expense: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update an expense
  Future<bool> updateExpense(ExpenseModel expense) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('groups')
          .doc(expense.groupId)
          .collection('expenses')
          .doc(expense.id)
          .update(expense.copyWith(updatedAt: DateTime.now()).toFirestore());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update expense: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete an expense (soft delete)
  Future<bool> deleteExpense(String groupId, String expenseId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get expense to reverse balances
      final expense = await getExpense(groupId, expenseId);
      if (expense == null) {
        _error = 'Expense not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get splits to reverse balances
      final splitsSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .collection('splits')
          .get();

      final batch = _firestore.batch();

      // Soft delete expense
      batch.update(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('expenses')
            .doc(expenseId),
        {'isDeleted': true, 'updatedAt': Timestamp.now()},
      );

      // Reverse member balances
      for (final splitDoc in splitsSnapshot.docs) {
        final split = SplitModel.fromFirestore(splitDoc);
        final netAmount = split.owedAmount - split.paidAmount;

        final memberRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(split.memberId);

        batch.update(memberRef, {
          'balance': FieldValue.increment(netAmount), // Reverse the change
        });
      }

      // Update group total expenses
      batch.update(_firestore.collection('groups').doc(groupId), {
        'totalExpenses': FieldValue.increment(-expense.amount),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete expense: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get splits for an expense
  Future<List<SplitModel>> getSplits(String groupId, String expenseId) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .collection('splits')
          .get();

      return snapshot.docs
          .map((doc) => SplitModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting splits: $e');
      return [];
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============================================
  // SETTLEMENT METHODS
  // ============================================

  /// Stream settlements for a group
  Stream<List<SettlementModel>> streamSettlements(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SettlementModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Create a settlement (payment between members)
  Future<SettlementModel?> createSettlement({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    String? fromUserId,
    String? toUserId,
    required double amount,
    String currencyCode = 'USD',
    required DateTime date,
    String? notes,
    String? proofImageUrl,
    required String createdBy,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final settlementRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .doc();

      final settlement = SettlementModel(
        id: settlementRef.id,
        groupId: groupId,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        currencyCode: currencyCode,
        date: date,
        notes: notes,
        proofImageUrl: proofImageUrl,
        createdBy: createdBy,
        createdAt: now,
        isConfirmed: false,
      );

      // Use batch for atomicity
      final batch = _firestore.batch();

      // Create settlement
      batch.set(settlementRef, settlement.toFirestore());

      // Update balances: fromMember pays (balance goes up/less debt)
      // toMember receives (balance goes down/less credit)
      final fromMemberRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(fromMemberId);

      final toMemberRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(toMemberId);

      batch.update(fromMemberRef, {
        'balance': FieldValue.increment(amount), // Payer balance increases
      });

      batch.update(toMemberRef, {
        'balance': FieldValue.increment(-amount), // Recipient balance decreases
      });

      // Update group timestamp
      batch.update(_firestore.collection('groups').doc(groupId), {
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return settlement;
    } catch (e) {
      _error = 'Failed to create settlement: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Confirm a settlement
  Future<bool> confirmSettlement(String groupId, String settlementId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .doc(settlementId)
          .update({
            'isConfirmed': true,
            'confirmedAt': Timestamp.now(),
          });
      return true;
    } catch (e) {
      debugPrint('Error confirming settlement: $e');
      return false;
    }
  }

  /// Get settlements for a group
  Future<List<SettlementModel>> getSettlements(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => SettlementModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting settlements: $e');
      return [];
    }
  }
}
