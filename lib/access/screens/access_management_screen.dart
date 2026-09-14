import 'package:flutter/material.dart';

import '../../services/friendly_auth_error.dart';
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

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _creating = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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

  /// Creates a new login and auto-selects it below so its flags can be
  /// adjusted immediately.
  Future<void> _create() async {
    if (_creating) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final emailOk =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final user =
          await _service.createAccount(email: email, password: password);
      _emailCtrl.clear();
      _passwordCtrl.clear();
      _pickUser(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account created for ${user.email}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyAuthError(e))),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
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
                  const Text('Create account',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'New user email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _create(),
                        decoration: InputDecoration(
                          labelText: 'Temporary password (min 6 chars)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _creating ? null : _create,
                          icon: _creating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.person_add_outlined,
                                  size: 18),
                          label: Text(
                              _creating ? 'Creating…' : 'Create account',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  const Text('Manage access',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
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
