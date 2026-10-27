/// Accounts that may view staff salary by default. Everyone else defaults
/// to disallowed (an admin can still override per account from Access
/// Management). Compared case-insensitively.
const List<String> salaryDefaultAllowEmails = [
  'dishu1bansal@gmail.com',
  'dishubansal81@gmail.com',
];

bool isSalaryDefaultAllowEmail(String? email) =>
    salaryDefaultAllowEmails.contains((email ?? '').trim().toLowerCase());

/// Access state for the signed-in user, resolved live from the `users`
/// Firestore collection (plus the hardcoded admin list).
class AppSession {
  final String uid;
  final String email;
  final bool isAdmin;
  final bool canAccessStudents;
  final bool canAccessFees;
  final bool canAccessStaff;
  final bool canViewStaffSalary;
  final bool canViewTotalPending;

  const AppSession({
    required this.uid,
    required this.email,
    required this.isAdmin,
    required this.canAccessStudents,
    required this.canAccessFees,
    required this.canAccessStaff,
    required this.canViewStaffSalary,
    required this.canViewTotalPending,
  });
}

/// One row of the `users` collection: an account the admin can manage.
class AppUser {
  final String uid;
  final String email;
  final bool canAccessStudents;
  final bool canAccessFees;
  final bool canAccessStaff;
  final bool canViewStaffSalary;
  final bool canViewTotalPending;

  const AppUser({
    required this.uid,
    required this.email,
    required this.canAccessStudents,
    required this.canAccessFees,
    required this.canAccessStaff,
    required this.canViewStaffSalary,
    required this.canViewTotalPending,
  });

  factory AppUser.fromDoc(String uid, Map<String, dynamic> d) {
    final email = (d['email'] ?? '').toString();
    return AppUser(
      uid: uid,
      email: email,
      canAccessStudents: d['canAccessStudents'] ?? true,
      canAccessFees: d['canAccessFees'] ?? true,
      canAccessStaff: d['canAccessStaff'] ?? true,
      canViewStaffSalary:
          d['canViewStaffSalary'] as bool? ?? isSalaryDefaultAllowEmail(email),
      canViewTotalPending: d['canViewTotalPending'] ?? false,
    );
  }
}
