import 'package:flutter/material.dart';

import '../models/student_model.dart';
import '../services/firebase_student_service.dart';
import 'student_form_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirebaseStudentService();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openForm([StudentModel? student]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(existing: student),
      ),
    );
  }

  Future<void> _delete(StudentModel student) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete'),
        content: Text('Delete "${student.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.delete(student.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.name} deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Student Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Students'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _StudentsTab(service: _service, onEdit: _openForm, onDelete: _delete),
          _LogsTab(service: _service),
        ],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: const Color(0xFF00695C),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Student',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

// ── Students tab ─────────────────────────────────────────────────────────────

class _StudentsTab extends StatelessWidget {
  final FirebaseStudentService service;
  final void Function(StudentModel?) onEdit;
  final void Function(StudentModel) onDelete;

  const _StudentsTab({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  String _initial(String name) =>
      name.isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentModel>>(
      stream: service.watchAll(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        final students = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting &&
            students.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (students.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No students yet.\nTap Add Student to create the first one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: students.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _StudentCard(
            student: students[i],
            onEdit: () => onEdit(students[i]),
            onDelete: () => onDelete(students[i]),
            initial: _initial(students[i].name),
          ),
        );
      },
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String initial;

  const _StudentCard({
    required this.student,
    required this.onEdit,
    required this.onDelete,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    final fees = student.fees.length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipOval(
              child: student.photoUrl.isNotEmpty
                  ? Image.network(
                      student.photoUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _avatar(initial),
                    )
                  : _avatar(initial),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Wrap(spacing: 6, runSpacing: 3, children: [
                    _chip(student.course),
                    _chip(student.college),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    'Admitted ${student.admissionYear}'
                    '${fees > 0 ? '  •  ${student.fees.length} fee '
                        '${student.fees.length == 1 ? 'entry' : 'entries'}'
                        ' (₹${student.totalFees.toStringAsFixed(0)})' : ''}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) =>
                  v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ])),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _avatar(String initial) {
    return Container(
      width: 46,
      height: 46,
      color: const Color(0xFF00695C).withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              color: Color(0xFF00695C),
              fontWeight: FontWeight.w700,
              fontSize: 18)),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00695C).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF00695C).withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF00695C))),
    );
  }
}

// ── Logs tab ─────────────────────────────────────────────────────────────────

class _LogsTab extends StatelessWidget {
  final FirebaseStudentService service;

  const _LogsTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentLog>>(
      stream: service.watchAllLogs(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load logs: ${snap.error}'));
        }
        final logs = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting && logs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (logs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No activity yet.\nStudent changes will be recorded here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _LogTile(log: logs[i]),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final StudentLog log;

  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (log.action) {
      'create' => (Icons.add_circle_outline, const Color(0xFF2E7D32)),
      'delete' => (Icons.delete_outline, Colors.red.shade600),
      _ => (Icons.edit_outlined, Colors.blue.shade700),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.action.toUpperCase()} — ${log.studentName}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                if (log.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(log.detail,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 4),
                Text(
                  '${_fmtDateTime(log.timestamp)}  •  by ${log.changedBy}',
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
