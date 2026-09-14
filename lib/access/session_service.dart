import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_session.dart';

/// Resolves the signed-in user's access flags live from Firestore.
///
/// Admins are hardcoded here and always have full access. Every other
/// account gets a `users/{uid}` document (auto-created with defaults on
/// first login); the admin edits its three flags from the Access
/// Management screen and changes stream to signed-in devices live.
class SessionService {
  /// Hardcoded admin emails (compared case-insensitively).
  static const List<String> adminEmails = ['pavitarpanghal@gmail.com'];

  static bool isAdminEmail(String? email) =>
      adminEmails.contains((email ?? '').trim().toLowerCase());

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _collection = 'users';

  /// Defaults for brand-new accounts: student + fees modules allowed,
  /// total pending fees hidden.
  static const bool _defaultStudents = true;
  static const bool _defaultFees = true;
  static const bool _defaultPending = false;

  /// Live session for the signed-in user (null when signed out).
  Stream<AppSession?> watchSession() {
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<AppSession?>.value(null);
      final email = (user.email ?? '').trim();
      if (isAdminEmail(email)) {
        return Stream<AppSession?>.value(AppSession(
          uid: user.uid,
          email: email,
          isAdmin: true,
          canAccessStudents: true,
          canAccessFees: true,
          canViewTotalPending: true,
        ));
      }
      return _db
          .collection(_collection)
          .doc(user.uid)
          .snapshots()
          .asyncMap((doc) async {
        if (!doc.exists) {
          final now = DateTime.now().toIso8601String();
          await _db.collection(_collection).doc(user.uid).set({
            'email': email,
            'canAccessStudents': _defaultStudents,
            'canAccessFees': _defaultFees,
            'canViewTotalPending': _defaultPending,
            'createdAt': now,
            'updatedAt': now,
            'updatedBy': email,
          });
          return AppSession(
            uid: user.uid,
            email: email,
            isAdmin: false,
            canAccessStudents: _defaultStudents,
            canAccessFees: _defaultFees,
            canViewTotalPending: _defaultPending,
          );
        }
        final d = doc.data()!;
        return AppSession(
          uid: user.uid,
          email: email,
          isAdmin: false,
          canAccessStudents: d['canAccessStudents'] ?? _defaultStudents,
          canAccessFees: d['canAccessFees'] ?? _defaultFees,
          canViewTotalPending: d['canViewTotalPending'] ?? _defaultPending,
        );
      });
    });
  }

  /// All accounts for the admin dropdown, ordered by email.
  Stream<List<AppUser>> watchUsers() {
    return _db
        .collection(_collection)
        .orderBy('email')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppUser.fromDoc(d.id, d.data())).toList());
  }

  /// Persists the three access flags for one account (admin only by policy).
  Future<void> updatePermissions({
    required String uid,
    required bool students,
    required bool fees,
    required bool pending,
  }) {
    final by = FirebaseAuth.instance.currentUser?.email ?? '';
    return _db.collection(_collection).doc(uid).update({
      'canAccessStudents': students,
      'canAccessFees': fees,
      'canViewTotalPending': pending,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': by,
    });
  }
}
