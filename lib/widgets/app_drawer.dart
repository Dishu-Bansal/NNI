import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../fees/screens/fees_management_screen.dart';
import '../screens/home_screen.dart';
import '../student_management/screens/student_list_screen.dart';

/// Shared side drawer used by the management screens: Home, Student
/// Management, Fees Management and Log Out.
Widget appDrawer(BuildContext context) {
  final user = FirebaseAuth.instance.currentUser;
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
                user?.email ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
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
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('Student Management'),
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentListScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Fees Management'),
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const FeesManagementScreen()),
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
}
