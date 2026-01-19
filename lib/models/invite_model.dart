import 'package:cloud_firestore/cloud_firestore.dart';

/// Invite model - for group invitations
class InviteModel {
  final String id;
  final String groupId;
  final String groupName;         // Denormalized for display
  final String createdBy;
  final String? email;            // If email invite
  final String inviteCode;        // Shareable code
  final DateTime expiresAt;
  final String? usedBy;           // User ID who used it
  final DateTime? usedAt;
  final bool isActive;
  final DateTime createdAt;

  InviteModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.createdBy,
    this.email,
    required this.inviteCode,
    required this.expiresAt,
    this.usedBy,
    this.usedAt,
    this.isActive = true,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory InviteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InviteModel(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      createdBy: data['createdBy'] ?? '',
      email: data['email'],
      inviteCode: data['inviteCode'] ?? doc.id,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
      usedBy: data['usedBy'],
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'createdBy': createdBy,
      'email': email,
      'inviteCode': inviteCode,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'usedBy': usedBy,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create a copy with updated fields
  InviteModel copyWith({
    String? usedBy,
    DateTime? usedAt,
    bool? isActive,
  }) {
    return InviteModel(
      id: id,
      groupId: groupId,
      groupName: groupName,
      createdBy: createdBy,
      email: email,
      inviteCode: inviteCode,
      expiresAt: expiresAt,
      usedBy: usedBy ?? this.usedBy,
      usedAt: usedAt ?? this.usedAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  /// Check if invite is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if invite has been used
  bool get isUsed => usedBy != null;

  /// Check if invite is valid (active, not expired, not used)
  bool get isValid => isActive && !isExpired && !isUsed;

  /// Get the shareable link
  String get shareLink => 'https://fairshare.app/join/$inviteCode';

  /// Get days until expiration
  int get daysUntilExpiry {
    final diff = expiresAt.difference(DateTime.now());
    return diff.inDays;
  }

  /// Get status text
  String get statusText {
    if (!isActive) return 'Deactivated';
    if (isUsed) return 'Used';
    if (isExpired) return 'Expired';
    return 'Active';
  }
}
