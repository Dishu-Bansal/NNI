import 'package:flutter/material.dart';

import '../access/app_session.dart';
import '../access/session_service.dart';
import '../fees/screens/fees_management_screen.dart';
import '../student_management/screens/student_list_screen.dart';
import '../widgets/app_drawer.dart';

/// Landing page shown after a successful login: quick links to the modules
/// the signed-in user may access (per their live access flags), and a side
/// drawer with a Log Out button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sessionService = SessionService();
  late final Stream<AppSession?> _sessionStream =
      _sessionService.watchSession();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSession?>(
      stream: _sessionStream,
      builder: (context, snap) {
        final session = snap.data;
        if (!snap.hasData || session == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final showStudents = session.canAccessStudents;
        final showFees = session.canAccessFees;
        return Scaffold(
          appBar: AppBar(title: const Text('NNI')),
          drawer: const AppDrawer(),
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
                    'Welcome${session.email.isNotEmpty ? ', ${session.email}' : ''}',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),
                  if (showStudents)
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
                  if (showStudents && showFees) const SizedBox(height: 12),
                  if (showFees)
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
                  if (!showStudents && !showFees) ...[
                    const SizedBox(height: 8),
                    Text(
                      'You currently have no module access.\nPlease contact the admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
