import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/app_user.dart';

/// All authentication and user-management logic.
///
/// Access model:
/// - There is NO self-signup. The only way to get an account is for an
///   admin to create one from inside the app (Admin > Users > Add user).
/// - Every account lives in Firebase Auth (email/password) AND has a
///   matching profile document in Firestore `users/{uid}` holding the
///   `role` (admin/user) and `status` (active/disabled).
/// - A user who is authenticated but `disabled` (or has no profile doc at
///   all — meaning their account was deleted/never finished provisioning)
///   is blocked at the app-shell level and shown a "no access" screen.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  // RTDB cannot read Firestore data in its security rules, so we mirror
  // each user's active/disabled status into a small node here. This is
  // what `firebase_rtdb_rules.json` checks to gate sensor data access —
  // it's kept in sync any time status changes via setUserStatus() or
  // adminCreateUser() below.
  DatabaseReference get _accessRef => FirebaseDatabase.instance.ref('access');

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Live stream of the signed-in user's own profile document.
  /// Emits null if not signed in or if the profile doc doesn't exist.
  Stream<AppUser?> currentUserProfileStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromDoc(doc);
    });
  }

  Future<AppUser?> fetchUserProfile(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  /// Sign in with email + password.
  /// Throws FirebaseAuthException on failure (wrong-password, user-not-found, etc).
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> changeOwnPassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await user.updatePassword(newPassword);
  }

  // ---------------------------------------------------------------------
  // Admin-only operations
  // ---------------------------------------------------------------------

  Stream<List<AppUser>> allUsersStream() {
    return _usersRef.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => AppUser.fromDoc(d)).toList(),
        );
  }

  /// Creates a brand-new account (Firebase Auth + Firestore profile) for
  /// someone the admin wants to grant access to. Uses a temporary secondary
  /// Firebase App instance so the currently signed-in admin is NOT signed
  /// out in the process — only the new account is created and immediately
  /// signed out of that secondary instance.
  Future<void> adminCreateUser({
    required String email,
    required String tempPassword,
    required String displayName,
    required AppRole role,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw Exception('Not signed in as admin');

    final secondaryAppName =
        'admin_create_${DateTime.now().millisecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: secondaryAppName,
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: tempPassword,
      );

      final newUid = credential.user?.uid;
      if (newUid == null) {
        throw Exception('Account creation did not return a user ID');
      }

      // Write the Firestore profile using the MAIN (admin) instance, since
      // security rules require an admin identity to create user docs.
      await _usersRef.doc(newUid).set({
        'email': email.trim(),
        'displayName': displayName.trim(),
        'role': role == AppRole.admin ? 'admin' : 'user',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminUid,
      });

      // Mirror into RTDB so Realtime Database security rules (which can't
      // see Firestore) can gate sensor-data access by status/role too.
      await _accessRef.child(newUid).set({
        'granted': true,
        'role': role == AppRole.admin ? 'admin' : 'user',
      });

      // Always sign the secondary instance out so the new account's
      // session doesn't linger anywhere.
      await secondaryAuth.signOut();
    } finally {
      // Always tear down the secondary app, even if something above failed,
      // so we don't leak app instances or partially-created sessions.
      await secondaryApp.delete();
    }
  }

  Future<void> setUserStatus(String uid, AccountStatus status) async {
    final isActive = status == AccountStatus.active;
    await _usersRef.doc(uid).update({
      'status': isActive ? 'active' : 'disabled',
    });
    // Keep the RTDB access mirror in sync so sensor-data rules see the
    // change immediately (RTDB rules can't read Firestore directly).
    // Uses update() (not set()) so we don't clobber the 'role' field.
    await _accessRef.child(uid).update({'granted': isActive});
  }

  Future<void> setUserRole(String uid, AppRole role) async {
    await _usersRef.doc(uid).update({
      'role': role == AppRole.admin ? 'admin' : 'user',
    });
    await _accessRef.child(uid).update({
      'role': role == AppRole.admin ? 'admin' : 'user',
    });
  }

  Future<void> deleteUserProfile(String uid) async {
    // Note: this removes the Firestore profile (revoking app access
    // immediately, since the app checks this doc), but cannot delete the
    // underlying Firebase Auth account from the client SDK — that requires
    // the Admin SDK on a backend. Disabling status is the recommended way
    // to revoke access from this client-only app; this delete is offered
    // for cleaning up the user list.
    await _usersRef.doc(uid).delete();
    await _accessRef.child(uid).remove();
  }
}
