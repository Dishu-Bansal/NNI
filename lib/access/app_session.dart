/// Access state for the signed-in user, resolved live from the `users`
/// Firestore collection (plus the hardcoded admin list).
class AppSession {
  final String uid;
  final String email;
  final bool isAdmin;
  final bool canAccessStudents;
  final bool canAccessFees;
  final bool canViewTotalPending;

  const AppSession({
    required this.uid,
    required this.email,
    required this.isAdmin,
    required this.canAccessStudents,
    required this.canAccessFees,
    required this.canViewTotalPending,
  });
}

/// One row of the `users` collection: an account the admin can manage.
class AppUser {
  final String uid;
  final String email;
  final bool canAccessStudents;
  final bool canAccessFees;
  final bool canViewTotalPending;

  const AppUser({
    required this.uid,
    required this.email,
    required this.canAccessStudents,
    required this.canAccessFees,
    required this.canViewTotalPending,
  });

  factory AppUser.fromDoc(String uid, Map<String, dynamic> d) => AppUser(
        uid: uid,
        email: (d['email'] ?? '').toString(),
        canAccessStudents: d['canAccessStudents'] ?? true,
        canAccessFees: d['canAccessFees'] ?? true,
        canViewTotalPending: d['canViewTotalPending'] ?? false,
      );
}
