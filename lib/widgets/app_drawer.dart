import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../access/app_session.dart';
import '../access/screens/access_management_screen.dart';
import '../access/session_service.dart';
import '../fees/screens/fees_management_screen.dart';
import '../screens/home_screen.dart';
import '../student_management/screens/student_list_screen.dart';

/// Shared side drawer used by the management screens. Entries follow the
/// signed-in user's access flags live; the Access Management entry is
/// visible only to admins.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _sessionService = SessionService();
  late final Stream<AppSession?> _sessionStream =
      _sessionService.watchSession();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSession?>(
      stream: _sessionStream,
      builder: (context, snap) {
        final session = snap.data;
        // While the session loads, show every entry; the screens enforce
        // access themselves, so this only avoids a flashing empty drawer.
        final showStudents = session == null || session.canAccessStudents;
        final showFees = session == null || session.canAccessFees;
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.local_hospital_outlined,
                        color: Colors.white, size: 34),
                    const SizedBox(height: 8),
                    const Text(
                      'National Nursing Institute',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      session?.email ?? '',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home'),
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
              ),
              if (showStudents)
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Student Management'),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StudentListScreen()),
                  ),
                ),
              if (showFees)
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Fees Management'),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FeesManagementScreen()),
                  ),
                ),
              if (session?.isAdmin == true)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Access Management'),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AccessManagementScreen()),
                  ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log Out'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
