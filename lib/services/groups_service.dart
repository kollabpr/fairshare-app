import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';

/// Service for managing expense sharing groups
class GroupsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<GroupModel> _groups = [];
  GroupModel? _selectedGroup;
  List<GroupMemberModel> _selectedGroupMembers = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<GroupModel> get groups => _groups;
  GroupModel? get selectedGroup => _selectedGroup;
  List<GroupMemberModel> get selectedGroupMembers => _selectedGroupMembers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Stream user's groups
  Stream<List<GroupModel>> streamGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          _groups = snapshot.docs
              .map((doc) => GroupModel.fromFirestore(doc))
              .where((g) => !g.isArchived)
              .toList();
          // Sort client-side to avoid needing composite index
          _groups.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          notifyListeners();
          return _groups;
        });
  }

  /// Get a single group by ID
  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      if (doc.exists) {
        return GroupModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting group: $e');
      return null;
    }
  }

  /// Create a new group
  Future<GroupModel?> createGroup({
    required String name,
    required String userId,
    String? description,
    String currencyCode = 'USD',
    String? iconName,
    String? colorHex,
    SplitType defaultSplitType = SplitType.equal,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final groupRef = _firestore.collection('groups').doc();

      final group = GroupModel(
        id: groupRef.id,
        name: name,
        description: description,
        createdBy: userId,
        currencyCode: currencyCode,
        iconName: iconName,
        colorHex: colorHex,
        defaultSplitType: defaultSplitType,
        createdAt: now,
        updatedAt: now,
        memberCount: 1,
      );

      // Create group document
      await groupRef.set({
        ...group.toFirestore(),
        'memberIds': [userId], // For querying user's groups
      });

      // Add creator as admin member
      await groupRef.collection('members').doc(userId).set(
        GroupMemberModel(
          id: userId,
          userId: userId,
          nickname: 'You', // Will be updated with actual name
          role: MemberRole.admin,
          joinedAt: now,
          inviteStatus: InviteStatus.accepted,
          isActive: true,
        ).toFirestore(),
      );

      _isLoading = false;
      notifyListeners();
      return group;
    } catch (e) {
      _error = 'Failed to create group: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update group settings
  Future<bool> updateGroup(GroupModel group) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('groups').doc(group.id).update({
        ...group.copyWith(updatedAt: DateTime.now()).toFirestore(),
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update group: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Archive a group (soft delete)
  Future<bool> archiveGroup(String groupId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'isArchived': true,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      _error = 'Failed to archive group: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stream members of a group
  Stream<List<GroupMemberModel>> streamMembers(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          _selectedGroupMembers = snapshot.docs
              .map((doc) => GroupMemberModel.fromFirestore(doc))
              .toList();
          notifyListeners();
          return _selectedGroupMembers;
        });
  }

  /// Get members of a group (one-time fetch)
  Future<List<GroupMemberModel>> getMembers(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => GroupMemberModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting members: $e');
      return [];
    }
  }

  /// Add a member to a group
  Future<GroupMemberModel?> addMember({
    required String groupId,
    required String nickname,
    String? userId,
    String? email,
    String? invitedBy,
    MemberRole role = MemberRole.member,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final memberRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(userId ?? _firestore.collection('temp').doc().id);

      final member = GroupMemberModel(
        id: memberRef.id,
        userId: userId,
        email: email,
        nickname: nickname,
        role: role,
        joinedAt: DateTime.now(),
        invitedBy: invitedBy,
        inviteStatus: userId != null ? InviteStatus.accepted : InviteStatus.pending,
        isActive: true,
      );

      await memberRef.set(member.toFirestore());

      // Update member count and memberIds array
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(1),
        if (userId != null) 'memberIds': FieldValue.arrayUnion([userId]),
        'updatedAt': Timestamp.now(),
      });

      _isLoading = false;
      notifyListeners();
      return member;
    } catch (e) {
      _error = 'Failed to add member: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Create a ghost member (for imported users not yet signed up)
  Future<GroupMemberModel?> createGhostMember(
    String groupId,
    String nickname,
  ) async {
    return addMember(
      groupId: groupId,
      nickname: nickname,
      userId: null,
    );
  }

  /// Update member's salary weight (for equity splitting)
  Future<bool> updateMemberWeight(
    String groupId,
    String memberId,
    double salaryWeight,
  ) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(memberId)
          .update({'salaryWeight': salaryWeight});
      return true;
    } catch (e) {
      debugPrint('Error updating member weight: $e');
      return false;
    }
  }

  /// Update member's balance (called when expenses are added/removed)
  Future<void> updateMemberBalance(
    String groupId,
    String memberId,
    double balanceChange,
  ) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(memberId)
          .update({
            'balance': FieldValue.increment(balanceChange),
          });
    } catch (e) {
      debugPrint('Error updating member balance: $e');
    }
  }

  /// Remove a member from a group
  Future<bool> removeMember(String groupId, String memberId) async {
    try {
      final memberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(memberId)
          .get();

      if (!memberDoc.exists) return false;

      final member = GroupMemberModel.fromFirestore(memberDoc);

      // Soft delete
      await memberDoc.reference.update({'isActive': false});

      // Update member count and memberIds
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(-1),
        if (member.userId != null)
          'memberIds': FieldValue.arrayRemove([member.userId]),
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      debugPrint('Error removing member: $e');
      return false;
    }
  }

  /// Select a group for viewing
  void selectGroup(GroupModel? group) {
    _selectedGroup = group;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
