import 'package:cloud_firestore/cloud_firestore.dart';

enum AppRole { admin, user }

enum AccountStatus { active, disabled }

/// Mirrors a document in the Firestore `users` collection.
/// Document ID == Firebase Auth UID.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final AppRole role;
  final AccountStatus status;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? lastSeenAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    this.createdAt,
    this.createdBy,
    this.lastSeenAt,
  });

  bool get isAdmin => role == AppRole.admin;
  bool get isActive => status == AccountStatus.active;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      role: (data['role'] as String?) == 'admin' ? AppRole.admin : AppRole.user,
      status: (data['status'] as String?) == 'disabled'
          ? AccountStatus.disabled
          : AccountStatus.active,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'role': role == AppRole.admin ? 'admin' : 'user',
        'status': status == AccountStatus.active ? 'active' : 'disabled',
      };
}
