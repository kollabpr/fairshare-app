import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/friend_model.dart';
import '../models/direct_expense_model.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';

/// Service for managing friends and direct expenses between users
class FriendsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<FriendModel> _friends = [];
  List<FriendModel> _pendingRequests = [];
  List<DirectExpenseModel> _directExpenses = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<FriendModel> get friends => _friends;
  List<FriendModel> get pendingRequests => _pendingRequests;
  List<FriendModel> get acceptedFriends =>
      _friends.where((f) => f.isAccepted).toList();
  List<DirectExpenseModel> get directExpenses => _directExpenses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Stream all friends for a user (all statuses)
  Stream<List<FriendModel>> streamFriends(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots()
        .map((snapshot) {
          _friends = snapshot.docs
              .map((doc) => FriendModel.fromFirestore(doc))
              .where((f) => !f.isBlocked)
              .toList();

          // Separate pending requests
          _pendingRequests = _friends
              .where((f) => f.isPending && f.requestedBy != userId)
              .toList();

          // Sort by most recent activity
          _friends.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          notifyListeners();
          return _friends;
        });
  }

  /// Stream only accepted friends
  Stream<List<FriendModel>> streamAcceptedFriends(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .where('status', isEqualTo: FriendStatus.accepted.name)
        .snapshots()
        .map((snapshot) {
          final acceptedList = snapshot.docs
              .map((doc) => FriendModel.fromFirestore(doc))
              .toList();
          acceptedList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return acceptedList;
        });
  }

  /// Stream pending incoming friend requests
  Stream<List<FriendModel>> streamPendingRequests(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .where('status', isEqualTo: FriendStatus.pending.name)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => FriendModel.fromFirestore(doc))
              .where((f) => f.requestedBy != userId) // Only incoming requests
              .toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  /// Search users by email or name
  Future<List<UserModel>> searchUsers(String query, String currentUserId) async {
    if (query.isEmpty || query.length < 2) return [];

    try {
      _isLoading = true;
      notifyListeners();

      final queryLower = query.toLowerCase();
      final results = <UserModel>[];

      // Search by exact email match
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: queryLower)
          .limit(5)
          .get();

      for (final doc in emailQuery.docs) {
        if (doc.id != currentUserId) {
          results.add(UserModel.fromFirestore(doc));
        }
      }

      // Also search by email prefix (for partial matching)
      // This requires a different approach since Firestore doesn't support LIKE queries
      // We use a range query on email field
      if (results.isEmpty) {
        final emailPrefixQuery = await _firestore
            .collection('users')
            .where('email', isGreaterThanOrEqualTo: queryLower)
            .where('email', isLessThan: '${queryLower}z')
            .limit(10)
            .get();

        for (final doc in emailPrefixQuery.docs) {
          if (doc.id != currentUserId) {
            final user = UserModel.fromFirestore(doc);
            if (!results.any((u) => u.uid == user.uid)) {
              results.add(user);
            }
          }
        }
      }

      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      debugPrint('Error searching users: $e');
      _error = 'Failed to search users: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Send a friend request by email
  Future<FriendModel?> sendFriendRequest({
    required String fromUserId,
    required String fromEmail,
    String? fromName,
    String? fromPhotoUrl,
    required String toEmail,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Find user by email
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: toEmail.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _error = 'No user found with that email address';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final targetUser = UserModel.fromFirestore(userQuery.docs.first);

      // Check if already friends or request pending
      final existingFriend = await _firestore
          .collection('users')
          .doc(fromUserId)
          .collection('friends')
          .where('friendUserId', isEqualTo: targetUser.uid)
          .limit(1)
          .get();

      if (existingFriend.docs.isNotEmpty) {
        final existing = FriendModel.fromFirestore(existingFriend.docs.first);
        if (existing.isAccepted) {
          _error = 'You are already friends with this user';
        } else if (existing.isPending) {
          _error = 'A friend request is already pending with this user';
        } else if (existing.isBlocked) {
          _error = 'Cannot send friend request to this user';
        }
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Cannot friend yourself
      if (targetUser.uid == fromUserId) {
        _error = 'You cannot add yourself as a friend';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final now = DateTime.now();
      final batch = _firestore.batch();

      // Create friend document for sender (outgoing request)
      final senderFriendRef = _firestore
          .collection('users')
          .doc(fromUserId)
          .collection('friends')
          .doc();

      // Create friend document for receiver (incoming request)
      final receiverFriendRef = _firestore
          .collection('users')
          .doc(targetUser.uid)
          .collection('friends')
          .doc();

      final senderFriend = FriendModel(
        id: senderFriendRef.id,
        odId: receiverFriendRef.id,
        status: FriendStatus.pending,
        friendUserId: targetUser.uid,
        friendEmail: targetUser.email,
        friendName: targetUser.displayName,
        friendPhotoUrl: targetUser.photoUrl,
        totalBalance: 0.0,
        requestedBy: fromUserId,
        createdAt: now,
        updatedAt: now,
      );

      final receiverFriend = FriendModel(
        id: receiverFriendRef.id,
        odId: senderFriendRef.id,
        status: FriendStatus.pending,
        friendUserId: fromUserId,
        friendEmail: fromEmail,
        friendName: fromName,
        friendPhotoUrl: fromPhotoUrl,
        totalBalance: 0.0,
        requestedBy: fromUserId,
        createdAt: now,
        updatedAt: now,
      );

      batch.set(senderFriendRef, senderFriend.toFirestore());
      batch.set(receiverFriendRef, receiverFriend.toFirestore());

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return senderFriend;
    } catch (e) {
      _error = 'Failed to send friend request: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest({
    required String userId,
    required String friendshipId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get the friend document
      final friendDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendshipId)
          .get();

      if (!friendDoc.exists) {
        _error = 'Friend request not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final friend = FriendModel.fromFirestore(friendDoc);

      if (!friend.isPending) {
        _error = 'This request has already been processed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final now = DateTime.now();
      final batch = _firestore.batch();

      // Update both sides of the friendship
      batch.update(friendDoc.reference, {
        'status': FriendStatus.accepted.name,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Update the other user's friend document
      if (friend.odId.isNotEmpty) {
        final otherFriendRef = _firestore
            .collection('users')
            .doc(friend.friendUserId)
            .collection('friends')
            .doc(friend.odId);

        batch.update(otherFriendRef, {
          'status': FriendStatus.accepted.name,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to accept friend request: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest({
    required String userId,
    required String friendshipId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get the friend document
      final friendDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendshipId)
          .get();

      if (!friendDoc.exists) {
        _error = 'Friend request not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final friend = FriendModel.fromFirestore(friendDoc);

      final batch = _firestore.batch();

      // Delete both sides of the friendship
      batch.delete(friendDoc.reference);

      // Delete the other user's friend document
      if (friend.odId.isNotEmpty) {
        final otherFriendRef = _firestore
            .collection('users')
            .doc(friend.friendUserId)
            .collection('friends')
            .doc(friend.odId);

        batch.delete(otherFriendRef);
      }

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to reject friend request: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Remove a friend (unfriend)
  Future<bool> removeFriend({
    required String userId,
    required String friendshipId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get the friend document
      final friendDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendshipId)
          .get();

      if (!friendDoc.exists) {
        _error = 'Friend not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final friend = FriendModel.fromFirestore(friendDoc);

      final batch = _firestore.batch();

      // Delete both sides of the friendship
      batch.delete(friendDoc.reference);

      // Delete the other user's friend document
      if (friend.odId.isNotEmpty) {
        final otherFriendRef = _firestore
            .collection('users')
            .doc(friend.friendUserId)
            .collection('friends')
            .doc(friend.odId);

        batch.delete(otherFriendRef);
      }

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to remove friend: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Block a friend
  Future<bool> blockFriend({
    required String userId,
    required String friendshipId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();

      // Update the friend document to blocked status
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendshipId)
          .update({
            'status': FriendStatus.blocked.name,
            'updatedAt': Timestamp.fromDate(now),
          });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to block friend: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get a single friend by ID
  Future<FriendModel?> getFriend(String userId, String friendshipId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendshipId)
          .get();

      if (doc.exists) {
        return FriendModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting friend: $e');
      return null;
    }
  }

  /// Get friend by friend user ID
  Future<FriendModel?> getFriendByUserId(String userId, String friendUserId) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .where('friendUserId', isEqualTo: friendUserId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return FriendModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting friend by user ID: $e');
      return null;
    }
  }

  // ============================================
  // DIRECT EXPENSES METHODS
  // ============================================

  /// Stream direct expenses with a specific friend
  Stream<List<DirectExpenseModel>> streamDirectExpenses(
    String userId,
    String friendUserId,
  ) {
    return _firestore
        .collection('directExpenses')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          _directExpenses = snapshot.docs
              .map((doc) => DirectExpenseModel.fromFirestore(doc))
              .where((e) =>
                  !e.isDeleted &&
                  e.participants.contains(friendUserId))
              .toList();
          _directExpenses.sort((a, b) => b.date.compareTo(a.date));
          notifyListeners();
          return _directExpenses;
        });
  }

  /// Stream all direct expenses for a user
  Stream<List<DirectExpenseModel>> streamAllDirectExpenses(String userId) {
    return _firestore
        .collection('directExpenses')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final expenses = snapshot.docs
              .map((doc) => DirectExpenseModel.fromFirestore(doc))
              .where((e) => !e.isDeleted)
              .toList();
          expenses.sort((a, b) => b.date.compareTo(a.date));
          return expenses;
        });
  }

  /// Create a direct expense between two friends
  Future<DirectExpenseModel?> createDirectExpense({
    required String description,
    required double amount,
    required String payerId,
    required String payerEmail,
    String? payerName,
    required String participantId,
    required String participantEmail,
    String? participantName,
    String currencyCode = 'USD',
    DateTime? date,
    String category = 'other',
    String? notes,
    String? receiptImageUrl,
    SplitType splitType = SplitType.equal,
    double? customPayerAmount,
    double? customParticipantAmount,
    required String createdBy,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Calculate split amounts
      double payerOwed = 0.0;
      double participantOwed = 0.0;

      if (customPayerAmount != null && customParticipantAmount != null) {
        payerOwed = customPayerAmount;
        participantOwed = customParticipantAmount;
      } else {
        // Equal split by default
        final halfAmount = amount / 2;
        payerOwed = 0.0; // Payer doesn't owe themselves
        participantOwed = halfAmount; // Participant owes half
      }

      final now = DateTime.now();
      final expenseRef = _firestore.collection('directExpenses').doc();

      final expense = DirectExpenseModel(
        id: expenseRef.id,
        description: description,
        amount: amount,
        currencyCode: currencyCode,
        payerId: payerId,
        payerEmail: payerEmail,
        payerName: payerName,
        participantId: participantId,
        participantEmail: participantEmail,
        participantName: participantName,
        participants: [payerId, participantId],
        date: date ?? now,
        category: category,
        notes: notes,
        receiptImageUrl: receiptImageUrl,
        splitType: splitType,
        payerOwedAmount: payerOwed,
        participantOwedAmount: participantOwed,
        createdBy: createdBy,
        createdAt: now,
        updatedAt: now,
      );

      final batch = _firestore.batch();

      // Create expense
      batch.set(expenseRef, expense.toFirestore());

      // Update friend balances
      // Payer's friend record: participant owes them money (positive balance)
      final payerFriendQuery = await _firestore
          .collection('users')
          .doc(payerId)
          .collection('friends')
          .where('friendUserId', isEqualTo: participantId)
          .limit(1)
          .get();

      if (payerFriendQuery.docs.isNotEmpty) {
        batch.update(payerFriendQuery.docs.first.reference, {
          'totalBalance': FieldValue.increment(participantOwed),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // Participant's friend record: they owe the payer (negative balance)
      final participantFriendQuery = await _firestore
          .collection('users')
          .doc(participantId)
          .collection('friends')
          .where('friendUserId', isEqualTo: payerId)
          .limit(1)
          .get();

      if (participantFriendQuery.docs.isNotEmpty) {
        batch.update(participantFriendQuery.docs.first.reference, {
          'totalBalance': FieldValue.increment(-participantOwed),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      await batch.commit();

      _isLoading = false;
      notifyListeners();
      return expense;
    } catch (e) {
      _error = 'Failed to create direct expense: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Delete a direct expense
  Future<bool> deleteDirectExpense(String expenseId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get the expense
      final expenseDoc = await _firestore
          .collection('directExpenses')
          .doc(expenseId)
          .get();

      if (!expenseDoc.exists) {
        _error = 'Expense not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final expense = DirectExpenseModel.fromFirestore(expenseDoc);
      final now = DateTime.now();
      final batch = _firestore.batch();

      // Soft delete the expense
      batch.update(expenseDoc.reference, {
        'isDeleted': true,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Reverse the balance changes
      // Payer's friend record: remove the positive balance
      final payerFriendQuery = await _firestore
          .collection('users')
          .doc(expense.payerId)
          .collection('friends')
          .where('friendUserId', isEqualTo: expense.participantId)
          .limit(1)
          .get();

      if (payerFriendQuery.docs.isNotEmpty) {
        batch.update(payerFriendQuery.docs.first.reference, {
          'totalBalance': FieldValue.increment(-expense.participantOwedAmount),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // Participant's friend record: remove the negative balance
      final participantFriendQuery = await _firestore
          .collection('users')
          .doc(expense.participantId)
          .collection('friends')
          .where('friendUserId', isEqualTo: expense.payerId)
          .limit(1)
          .get();

      if (participantFriendQuery.docs.isNotEmpty) {
        batch.update(participantFriendQuery.docs.first.reference, {
          'totalBalance': FieldValue.increment(expense.participantOwedAmount),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

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

  /// Get direct expense by ID
  Future<DirectExpenseModel?> getDirectExpense(String expenseId) async {
    try {
      final doc = await _firestore
          .collection('directExpenses')
          .doc(expenseId)
          .get();

      if (doc.exists) {
        return DirectExpenseModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting direct expense: $e');
      return null;
    }
  }

  // ============================================
  // DIRECT SETTLEMENTS METHODS
  // ============================================

  /// Stream direct settlements with a specific friend
  Stream<List<DirectSettlementModel>> streamDirectSettlements(
    String userId,
    String friendUserId,
  ) {
    return _firestore
        .collection('directSettlements')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final settlements = snapshot.docs
              .map((doc) => DirectSettlementModel.fromFirestore(doc))
              .where((s) => s.participants.contains(friendUserId))
              .toList();
          settlements.sort((a, b) => b.date.compareTo(a.date));
          return settlements;
        });
  }

  /// Create a direct settlement between two friends
  Future<DirectSettlementModel?> createDirectSettlement({
    required String fromUserId,
    required String fromEmail,
    String? fromName,
    required String toUserId,
    required String toEmail,
    String? toName,
    required double amount,
    String currencyCode = 'USD',
    DateTime? date,
    String? notes,
    String? proofImageUrl,
    required String createdBy,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final settlementRef = _firestore.collection('directSettlements').doc();

      final settlement = DirectSettlementModel(
        id: settlementRef.id,
        fromUserId: fromUserId,
        fromEmail: fromEmail,
        fromName: fromName,
        toUserId: toUserId,
        toEmail: toEmail,
        toName: toName,
        participants: [fromUserId, toUserId],
        amount: amount,
        currencyCode: currencyCode,
        date: date ?? now,
        notes: notes,
        proofImageUrl: proofImageUrl,
        createdBy: createdBy,
        createdAt: now,
      );

      final batch = _firestore.batch();

      // Create settlement
      batch.set(settlementRef, settlement.toFirestore());

      // Update friend balances
      // fromUser paid toUser, so fromUser is owed money (positive balance)
      final fromUserFriendQuery = await _firestore
          .collection('users')
          .doc(fromUserId)
          .collection('friends')
          .where('friendUserId', isEqualTo: toUserId)
          .limit(1)
          .get();

      if (fromUserFriendQuery.docs.isNotEmpty) {
        batch.update(fromUserFriendQuery.docs.first.reference, {
          'totalBalance': FieldValue.increment(amount),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // toUser received from fromUser, so they owe (negative balance)
      final toUserFriendQuery = await _firestore
          .collection('users')
          .doc(toUserId)
          .collection('friends')
          .where('friendUserId', isEqualTo: fromUserId)
          .limit(1)
          .get();

      if (toUserFriendQuery.docs.isNotEmpty) {
        batch.update(toUserFriendQuery.docs.first.reference, {
          'totalBalance': FieldValue.increment(-amount),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

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

  /// Confirm a direct settlement
  Future<bool> confirmDirectSettlement(String settlementId) async {
    try {
      await _firestore
          .collection('directSettlements')
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

  // ============================================
  // BALANCE CALCULATION METHODS
  // ============================================

  /// Calculate total balance with a specific friend from direct expenses
  Future<double> getFriendBalance(String userId, String friendUserId) async {
    try {
      // Get all direct expenses between these two users
      final expensesSnapshot = await _firestore
          .collection('directExpenses')
          .where('participants', arrayContains: userId)
          .get();

      double balance = 0.0;

      for (final doc in expensesSnapshot.docs) {
        final expense = DirectExpenseModel.fromFirestore(doc);

        if (expense.isDeleted || !expense.participants.contains(friendUserId)) {
          continue;
        }

        balance += expense.getBalanceForUser(userId);
      }

      // Also consider settlements
      final settlementsSnapshot = await _firestore
          .collection('directSettlements')
          .where('participants', arrayContains: userId)
          .get();

      for (final doc in settlementsSnapshot.docs) {
        final settlement = DirectSettlementModel.fromFirestore(doc);

        if (!settlement.participants.contains(friendUserId)) {
          continue;
        }

        balance += settlement.getBalanceForUser(userId);
      }

      return balance;
    } catch (e) {
      debugPrint('Error calculating friend balance: $e');
      return 0.0;
    }
  }

  /// Recalculate and update friend balance (useful for data consistency)
  Future<void> recalculateFriendBalance(String userId, String friendUserId) async {
    try {
      final balance = await getFriendBalance(userId, friendUserId);
      final now = DateTime.now();

      // Update user's friend record
      final userFriendQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .where('friendUserId', isEqualTo: friendUserId)
          .limit(1)
          .get();

      if (userFriendQuery.docs.isNotEmpty) {
        await userFriendQuery.docs.first.reference.update({
          'totalBalance': balance,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // Update friend's friend record (with inverted balance)
      final friendFriendQuery = await _firestore
          .collection('users')
          .doc(friendUserId)
          .collection('friends')
          .where('friendUserId', isEqualTo: userId)
          .limit(1)
          .get();

      if (friendFriendQuery.docs.isNotEmpty) {
        await friendFriendQuery.docs.first.reference.update({
          'totalBalance': -balance,
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    } catch (e) {
      debugPrint('Error recalculating friend balance: $e');
    }
  }

  /// Get all balances summary for a user
  Future<Map<String, double>> getAllFriendBalances(String userId) async {
    try {
      final balances = <String, double>{};

      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .where('status', isEqualTo: FriendStatus.accepted.name)
          .get();

      for (final doc in friendsSnapshot.docs) {
        final friend = FriendModel.fromFirestore(doc);
        balances[friend.friendUserId] = friend.totalBalance;
      }

      return balances;
    } catch (e) {
      debugPrint('Error getting friend balances: $e');
      return {};
    }
  }

  /// Get total amount owed to user by all friends
  Future<double> getTotalOwedToUser(String userId) async {
    final balances = await getAllFriendBalances(userId);
    return balances.values.where((b) => b > 0).fold<double>(0.0, (double total, double b) => total + b);
  }

  /// Get total amount user owes to all friends
  Future<double> getTotalOwedByUser(String userId) async {
    final balances = await getAllFriendBalances(userId);
    return balances.values.where((b) => b < 0).fold<double>(0.0, (double total, double b) => total + b.abs());
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
