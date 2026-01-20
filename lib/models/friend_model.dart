import 'package:cloud_firestore/cloud_firestore.dart';

/// Friend status enum for tracking friendship state
enum FriendStatus {
  pending,   // Friend request sent but not accepted
  accepted,  // Friendship is active
  blocked,   // User has blocked this friend
}

/// Friend model - represents a friendship between two users
/// Stored at /users/{userId}/friends/{friendId}
class FriendModel {
  final String id;
  final String odId;               // The other direction's document ID (for easy deletion)
  final FriendStatus status;
  final String friendUserId;       // The friend's user ID
  final String friendEmail;        // The friend's email
  final String? friendName;        // The friend's display name
  final String? friendPhotoUrl;    // The friend's profile photo
  final double totalBalance;       // Positive = they owe you, negative = you owe them
  final String? requestedBy;       // Who initiated the friend request
  final DateTime createdAt;
  final DateTime updatedAt;

  FriendModel({
    required this.id,
    this.odId = '',
    required this.status,
    required this.friendUserId,
    required this.friendEmail,
    this.friendName,
    this.friendPhotoUrl,
    this.totalBalance = 0.0,
    this.requestedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory FriendModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendModel(
      id: doc.id,
      odId: data['odId'] ?? '',
      status: FriendStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => FriendStatus.pending,
      ),
      friendUserId: data['friendUserId'] ?? '',
      friendEmail: data['friendEmail'] ?? '',
      friendName: data['friendName'],
      friendPhotoUrl: data['friendPhotoUrl'],
      totalBalance: (data['totalBalance'] ?? 0).toDouble(),
      requestedBy: data['requestedBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'odId': odId,
      'status': status.name,
      'friendUserId': friendUserId,
      'friendEmail': friendEmail,
      'friendName': friendName,
      'friendPhotoUrl': friendPhotoUrl,
      'totalBalance': totalBalance,
      'requestedBy': requestedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  FriendModel copyWith({
    String? odId,
    FriendStatus? status,
    String? friendEmail,
    String? friendName,
    String? friendPhotoUrl,
    double? totalBalance,
    DateTime? updatedAt,
  }) {
    return FriendModel(
      id: id,
      odId: odId ?? this.odId,
      status: status ?? this.status,
      friendUserId: friendUserId,
      friendEmail: friendEmail ?? this.friendEmail,
      friendName: friendName ?? this.friendName,
      friendPhotoUrl: friendPhotoUrl ?? this.friendPhotoUrl,
      totalBalance: totalBalance ?? this.totalBalance,
      requestedBy: requestedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this is a pending friend request
  bool get isPending => status == FriendStatus.pending;

  /// Check if this friendship is active
  bool get isAccepted => status == FriendStatus.accepted;

  /// Check if this friend is blocked
  bool get isBlocked => status == FriendStatus.blocked;

  /// Check if the current user sent this friend request
  bool isSentByMe(String currentUserId) => requestedBy == currentUserId;

  /// Check if this is an incoming friend request
  bool isIncomingRequest(String currentUserId) =>
      isPending && requestedBy != currentUserId;

  /// Check if this is an outgoing friend request
  bool isOutgoingRequest(String currentUserId) =>
      isPending && requestedBy == currentUserId;

  /// Get display name or email prefix
  String get displayName => friendName ?? friendEmail.split('@').first;

  /// Get initials for avatar
  String get initials {
    final name = friendName ?? friendEmail;
    final parts = name.split(RegExp(r'[\s@]'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  /// Get balance status text
  String get balanceStatus {
    if (totalBalance.abs() < 0.01) return 'settled up';
    if (totalBalance > 0) return 'owes you';
    return 'you owe';
  }

  /// Get formatted balance
  String getFormattedBalance({String currencySymbol = '\$'}) {
    if (totalBalance.abs() < 0.01) return 'settled up';
    final absBalance = totalBalance.abs().toStringAsFixed(2);
    if (totalBalance > 0) {
      return 'owes you $currencySymbol$absBalance';
    }
    return 'you owe $currencySymbol$absBalance';
  }
}
