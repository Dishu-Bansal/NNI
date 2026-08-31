import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../fees/screens/fees_management_screen.dart';
import '../student_management/screens/student_list_screen.dart';
import '../widgets/app_drawer.dart';

/// Landing page shown after a successful login: a success message, quick
/// links to the management screens, and a side drawer with a Log Out button.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('NNI')),
      drawer: appDrawer(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 72, color: Color(0xFF2E7D32)),
              const SizedBox(height: 16),
              const Text(
                'Login Successful',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome${user?.email != null ? ', ${user!.email}' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const StudentListScreen()),
                  ),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Student Management'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FeesManagementScreen()),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Fees Management'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
