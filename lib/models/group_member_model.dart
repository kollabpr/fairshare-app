import 'package:cloud_firestore/cloud_firestore.dart';

/// Role in a group
enum MemberRole {
  admin,  // Can edit group, add/remove members
  member, // Can add expenses
}

/// Invite status for group members
enum InviteStatus {
  pending,  // Invite sent but not accepted
  accepted, // User has joined
  declined, // User declined invite
}

/// Group member model - represents a user's membership in a group
/// Supports both registered users and "ghost users" (not yet signed up)
class GroupMemberModel {
  final String id;
  final String? userId;           // Null for ghost users
  final String? email;            // For pending invites
  final String nickname;          // Display name in this group
  final MemberRole role;
  final double salaryWeight;      // For equity splitting (default 1.0)
  final DateTime joinedAt;
  final String? invitedBy;        // User ID who invited
  final InviteStatus inviteStatus;
  final double balance;           // Denormalized: positive = owed, negative = owes
  final bool isActive;

  GroupMemberModel({
    required this.id,
    this.userId,
    this.email,
    required this.nickname,
    this.role = MemberRole.member,
    this.salaryWeight = 1.0,
    required this.joinedAt,
    this.invitedBy,
    this.inviteStatus = InviteStatus.accepted,
    this.balance = 0.0,
    this.isActive = true,
  });

  /// Create from Firestore document
  factory GroupMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupMemberModel(
      id: doc.id,
      userId: data['userId'],
      email: data['email'],
      nickname: data['nickname'] ?? 'Unknown',
      role: MemberRole.values.firstWhere(
        (e) => e.name == (data['role'] ?? 'member'),
        orElse: () => MemberRole.member,
      ),
      salaryWeight: (data['salaryWeight'] ?? 1.0).toDouble(),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      invitedBy: data['invitedBy'],
      inviteStatus: InviteStatus.values.firstWhere(
        (e) => e.name == (data['inviteStatus'] ?? 'accepted'),
        orElse: () => InviteStatus.accepted,
      ),
      balance: (data['balance'] ?? 0).toDouble(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'nickname': nickname,
      'role': role.name,
      'salaryWeight': salaryWeight,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'invitedBy': invitedBy,
      'inviteStatus': inviteStatus.name,
      'balance': balance,
      'isActive': isActive,
    };
  }

  /// Create a copy with updated fields
  GroupMemberModel copyWith({
    String? userId,
    String? email,
    String? nickname,
    MemberRole? role,
    double? salaryWeight,
    String? invitedBy,
    InviteStatus? inviteStatus,
    double? balance,
    bool? isActive,
  }) {
    return GroupMemberModel(
      id: id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
      salaryWeight: salaryWeight ?? this.salaryWeight,
      joinedAt: joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      inviteStatus: inviteStatus ?? this.inviteStatus,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Check if this is a ghost user (no account yet)
  bool get isGhostUser => userId == null;

  /// Check if this member is an admin
  bool get isAdmin => role == MemberRole.admin;

  /// Check if invite is pending
  bool get isPending => inviteStatus == InviteStatus.pending;

  /// Get initials for avatar
  String get initials {
    final parts = nickname.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nickname.substring(0, nickname.length.clamp(0, 2)).toUpperCase();
  }

  /// Get balance status text
  String get balanceStatus {
    if (balance.abs() < 0.01) return 'settled up';
    if (balance > 0) return 'gets back';
    return 'owes';
  }
}
