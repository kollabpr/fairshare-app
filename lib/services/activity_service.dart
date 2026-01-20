import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_model.dart';

/// Service for managing the activity feed
class ActivityService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ActivityModel> _activities = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ActivityModel> get activities => _activities;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUnread => _unreadCount > 0;

  /// Stream activities for a user
  /// Activities are stored under /users/{userId}/activities/{activityId}
  Stream<List<ActivityModel>> streamActivities(String userId, {int? limit}) {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('activities')
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      _activities = snapshot.docs
          .map((doc) => ActivityModel.fromFirestore(doc))
          .toList();
      _unreadCount = _activities.where((a) => !a.isRead).length;
      notifyListeners();
      return _activities;
    });
  }

  /// Get activities for a user (one-time fetch)
  Future<List<ActivityModel>> getActivities(String userId, {int? limit}) async {
    try {
      _isLoading = true;
      notifyListeners();

      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('activities')
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      _activities = snapshot.docs
          .map((doc) => ActivityModel.fromFirestore(doc))
          .toList();
      _unreadCount = _activities.where((a) => !a.isRead).length;

      _isLoading = false;
      notifyListeners();
      return _activities;
    } catch (e) {
      _error = 'Failed to load activities: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error getting activities: $e');
      return [];
    }
  }

  /// Log a new activity
  /// This creates activities for all relevant users
  Future<ActivityModel?> logActivity({
    required ActivityType type,
    required String userId,
    required String description,
    String? targetUserId,
    String? groupId,
    String? expenseId,
    String? settlementId,
    double? amount,
    Map<String, dynamic> metadata = const {},
    List<String>? notifyUserIds,
  }) async {
    try {
      final now = DateTime.now();

      // Create the activity for the actor
      final actorActivityRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('activities')
          .doc();

      final activity = ActivityModel(
        id: actorActivityRef.id,
        type: type,
        userId: userId,
        targetUserId: targetUserId,
        groupId: groupId,
        expenseId: expenseId,
        settlementId: settlementId,
        amount: amount,
        description: description,
        metadata: metadata,
        createdAt: now,
        isRead: true, // Actor's own activity is marked as read
      );

      final batch = _firestore.batch();

      // Save activity for the actor
      batch.set(actorActivityRef, activity.toFirestore());

      // Create activities for other users to notify
      if (notifyUserIds != null) {
        for (final notifyUserId in notifyUserIds) {
          if (notifyUserId == userId) continue; // Skip actor

          final notifyActivityRef = _firestore
              .collection('users')
              .doc(notifyUserId)
              .collection('activities')
              .doc();

          batch.set(notifyActivityRef, {
            ...activity.toFirestore(),
            'id': notifyActivityRef.id,
            'isRead': false, // Unread for others
          });
        }
      }

      await batch.commit();
      return activity;
    } catch (e) {
      _error = 'Failed to log activity: $e';
      notifyListeners();
      debugPrint('Error logging activity: $e');
      return null;
    }
  }

  /// Log activity for expense added
  Future<ActivityModel?> logExpenseAdded({
    required String userId,
    required String actorName,
    required String groupId,
    required String groupName,
    required String expenseId,
    required String expenseDescription,
    required double amount,
    required List<String> groupMemberUserIds,
    String currencySymbol = '\$',
  }) async {
    return logActivity(
      type: ActivityType.expenseAdded,
      userId: userId,
      description: '$actorName added "$expenseDescription" for $currencySymbol${amount.toStringAsFixed(2)}',
      groupId: groupId,
      expenseId: expenseId,
      amount: amount,
      metadata: {
        'actorName': actorName,
        'groupName': groupName,
        'expenseDescription': expenseDescription,
        'currencySymbol': currencySymbol,
      },
      notifyUserIds: groupMemberUserIds,
    );
  }

  /// Log activity for expense deleted
  Future<ActivityModel?> logExpenseDeleted({
    required String userId,
    required String actorName,
    required String groupId,
    required String groupName,
    required String expenseDescription,
    required double amount,
    required List<String> groupMemberUserIds,
    String currencySymbol = '\$',
  }) async {
    return logActivity(
      type: ActivityType.expenseDeleted,
      userId: userId,
      description: '$actorName deleted "$expenseDescription"',
      groupId: groupId,
      amount: amount,
      metadata: {
        'actorName': actorName,
        'groupName': groupName,
        'expenseDescription': expenseDescription,
        'currencySymbol': currencySymbol,
      },
      notifyUserIds: groupMemberUserIds,
    );
  }

  /// Log activity for settlement recorded
  Future<ActivityModel?> logSettlementRecorded({
    required String userId,
    required String actorName,
    required String targetUserId,
    required String targetName,
    required String groupId,
    required String groupName,
    required String settlementId,
    required double amount,
    required List<String> groupMemberUserIds,
    String currencySymbol = '\$',
  }) async {
    return logActivity(
      type: ActivityType.settlementRecorded,
      userId: userId,
      description: '$actorName paid $targetName $currencySymbol${amount.toStringAsFixed(2)}',
      targetUserId: targetUserId,
      groupId: groupId,
      settlementId: settlementId,
      amount: amount,
      metadata: {
        'actorName': actorName,
        'targetName': targetName,
        'groupName': groupName,
        'currencySymbol': currencySymbol,
      },
      notifyUserIds: groupMemberUserIds,
    );
  }

  /// Log activity for settlement confirmed
  Future<ActivityModel?> logSettlementConfirmed({
    required String userId,
    required String actorName,
    required String payerUserId,
    required String payerName,
    required String groupId,
    required String groupName,
    required String settlementId,
    required double amount,
    required List<String> groupMemberUserIds,
    String currencySymbol = '\$',
  }) async {
    return logActivity(
      type: ActivityType.settlementConfirmed,
      userId: userId,
      description: '$actorName confirmed payment of $currencySymbol${amount.toStringAsFixed(2)} from $payerName',
      targetUserId: payerUserId,
      groupId: groupId,
      settlementId: settlementId,
      amount: amount,
      metadata: {
        'actorName': actorName,
        'payerName': payerName,
        'groupName': groupName,
        'currencySymbol': currencySymbol,
      },
      notifyUserIds: groupMemberUserIds,
    );
  }

  /// Log activity for group created
  Future<ActivityModel?> logGroupCreated({
    required String userId,
    required String actorName,
    required String groupId,
    required String groupName,
  }) async {
    return logActivity(
      type: ActivityType.groupCreated,
      userId: userId,
      description: '$actorName created "$groupName"',
      groupId: groupId,
      metadata: {
        'actorName': actorName,
        'groupName': groupName,
      },
    );
  }

  /// Log activity for joining a group
  Future<ActivityModel?> logGroupJoined({
    required String userId,
    required String actorName,
    required String groupId,
    required String groupName,
    required List<String> groupMemberUserIds,
  }) async {
    return logActivity(
      type: ActivityType.groupJoined,
      userId: userId,
      description: '$actorName joined "$groupName"',
      groupId: groupId,
      metadata: {
        'actorName': actorName,
        'groupName': groupName,
      },
      notifyUserIds: groupMemberUserIds,
    );
  }

  /// Log activity for member added
  Future<ActivityModel?> logMemberAdded({
    required String userId,
    required String actorName,
    required String targetName,
    required String groupId,
    required String groupName,
    required List<String> groupMemberUserIds,
    String? targetUserId,
  }) async {
    return logActivity(
      type: ActivityType.memberAdded,
      userId: userId,
      description: '$actorName added $targetName to "$groupName"',
      targetUserId: targetUserId,
      groupId: groupId,
      metadata: {
        'actorName': actorName,
        'targetName': targetName,
        'groupName': groupName,
      },
      notifyUserIds: groupMemberUserIds,
    );
  }

  /// Log activity for friend added
  Future<ActivityModel?> logFriendAdded({
    required String userId,
    required String actorName,
    required String targetUserId,
    required String targetName,
  }) async {
    return logActivity(
      type: ActivityType.friendAdded,
      userId: userId,
      description: '$actorName added $targetName as a friend',
      targetUserId: targetUserId,
      metadata: {
        'actorName': actorName,
        'targetName': targetName,
      },
      notifyUserIds: [targetUserId],
    );
  }

  /// Mark a single activity as read
  Future<bool> markAsRead(String userId, String activityId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('activities')
          .doc(activityId)
          .update({'isRead': true});

      // Update local state
      final index = _activities.indexWhere((a) => a.id == activityId);
      if (index != -1) {
        _activities[index] = _activities[index].copyWith(isRead: true);
        _unreadCount = _activities.where((a) => !a.isRead).length;
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error marking activity as read: $e');
      return false;
    }
  }

  /// Mark all activities as read for a user
  Future<bool> markAllAsRead(String userId) async {
    try {
      // Get all unread activities
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('activities')
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return true;

      // Batch update all to read
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      // Update local state
      _activities = _activities.map((a) => a.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error marking all activities as read: $e');
      return false;
    }
  }

  /// Get unread count for a user
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('activities')
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      _unreadCount = snapshot.count ?? 0;
      notifyListeners();
      return _unreadCount;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Stream unread count for a user
  Stream<int> streamUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('activities')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          _unreadCount = snapshot.docs.length;
          notifyListeners();
          return _unreadCount;
        });
  }

  /// Delete old activities (for cleanup)
  Future<int> deleteOldActivities(String userId, {int daysToKeep = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('activities')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (snapshot.docs.isEmpty) return 0;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error deleting old activities: $e');
      return 0;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Group activities by date
  Map<String, List<ActivityModel>> groupActivitiesByDate(List<ActivityModel> activities) {
    final grouped = <String, List<ActivityModel>>{};

    for (final activity in activities) {
      final group = activity.dateGroup;
      if (!grouped.containsKey(group)) {
        grouped[group] = [];
      }
      grouped[group]!.add(activity);
    }

    return grouped;
  }
}
