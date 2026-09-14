import 'package:flutter/material.dart';

import '../../widgets/app_drawer.dart';
import '../app_session.dart';
import '../session_service.dart';
import '../widgets/no_access_screen.dart';

/// Admin-only screen: pick any non-admin account from a dropdown, see its
/// current access flags, change them and save. Changes stream to the user's
/// signed-in devices live.
class AccessManagementScreen extends StatefulWidget {
  const AccessManagementScreen({super.key});

  @override
  State<AccessManagementScreen> createState() =>
      _AccessManagementScreenState();
}

class _AccessManagementScreenState extends State<AccessManagementScreen> {
  final _service = SessionService();
  late final Stream<AppSession?> _sessionStream =
      _service.watchSession();
  late final Stream<List<AppUser>> _usersStream = _service.watchUsers();

  String? _selectedUid;
  bool _students = true;
  bool _fees = true;
  bool _pending = false;
  bool _saving = false;

  void _pickUser(AppUser? user) {
    setState(() {
      _selectedUid = user?.uid;
      _students = user?.canAccessStudents ?? true;
      _fees = user?.canAccessFees ?? true;
      _pending = user?.canViewTotalPending ?? false;
    });
  }

  Future<void> _save() async {
    final uid = _selectedUid;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _service.updatePermissions(
        uid: uid,
        students: _students,
        fees: _fees,
        pending: _pending,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSession?>(
      stream: _sessionStream,
      builder: (context, sessionSnap) {
        final session = sessionSnap.data;
        if (!sessionSnap.hasData || session == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!session.isAdmin) {
          return noAccessScaffold(
              module: 'Access Management', drawer: const AppDrawer());
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: const Text('Access Management',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: StreamBuilder<List<AppUser>>(
            stream: _usersStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              // Admin accounts are managed in code, not from this list.
              final users = (snap.data ?? [])
                  .where((u) => !SessionService.isAdminEmail(u.email))
                  .toList();
              final selected = users.where((u) => u.uid == _selectedUid);
              if (users.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No user accounts yet.\nAccounts appear here after their first login.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedUid,
                    decoration: const InputDecoration(
                      labelText: 'User Account',
                      prefixIcon: Icon(Icons.manage_accounts_outlined),
                    ),
                    items: [
                      for (final u in users)
                        DropdownMenuItem(
                          value: u.uid,
                          child: Text(u.email.isEmpty ? '(no email)' : u.email,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (uid) {
                      if (uid == null) {
                        _pickUser(null);
                        return;
                      }
                      final match =
                          users.where((u) => u.uid == uid).firstOrNull;
                      _pickUser(match);
                    },
                  ),
                  if (selected.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Access',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    _accessRow('Access Student Management', _students,
                        (v) => setState(() => _students = v)),
                    const SizedBox(height: 12),
                    _accessRow('Access Fees Management', _fees,
                        (v) => setState(() => _fees = v)),
                    const SizedBox(height: 12),
                    _accessRow('View Total Pending Fees', _pending,
                        (v) => setState(() => _pending = v)),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(_saving ? 'Saving…' : 'Save Access',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _accessRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Allow')),
            ButtonSegment(value: false, label: Text('Disallow')),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ]),
    );
  }
}
