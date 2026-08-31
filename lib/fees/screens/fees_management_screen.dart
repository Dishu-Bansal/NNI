import 'package:flutter/material.dart';

import '../../student_management/models/student_model.dart';
import '../../student_management/services/firebase_student_service.dart';
import '../models/receipt_model.dart';
import '../services/firebase_fees_service.dart';
import 'receipt_form_screen.dart';
import 'student_fees_detail_screen.dart';

/// Fees Management: a Students table (current year first, pending
/// highlighted), latest Receipts, and a Receipts log.
class FeesManagementScreen extends StatefulWidget {
  const FeesManagementScreen({super.key});

  @override
  State<FeesManagementScreen> createState() => _FeesManagementScreenState();
}

class _FeesManagementScreenState extends State<FeesManagementScreen>
    with SingleTickerProviderStateMixin {
  final _feesService = FirebaseFeesService();
  final _studentService = FirebaseStudentService();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openReceiptForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptFormScreen()),
    );
  }

  void _openStudentFees(StudentModel student) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => StudentFeesDetailScreen(student: student)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Fees Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Students'),
            Tab(
                icon: Icon(Icons.receipt_long_outlined, size: 18),
                text: 'Receipts'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _StudentsTab(
            studentService: _studentService,
            feesService: _feesService,
            onOpen: _openStudentFees,
          ),
          _ReceiptsTab(service: _feesService),
          _LogsTab(service: _feesService),
        ],
      ),
      floatingActionButton: _tabs.index <= 1
          ? FloatingActionButton.extended(
              onPressed: _openReceiptForm,
              backgroundColor: const Color(0xFF1A3C6E),
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text('Add Receipt',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

// ── Students tab ─────────────────────────────────────────────────────────────

class _StudentsTab extends StatelessWidget {
  final FirebaseStudentService studentService;
  final FirebaseFeesService feesService;
  final void Function(StudentModel) onOpen;

  const _StudentsTab({
    required this.studentService,
    required this.feesService,
    required this.onOpen,
  });

  String _money(double v) => '₹${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentModel>>(
      stream: studentService.watchAll(),
      builder: (context, studentSnap) {
        if (studentSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final students = studentSnap.data ?? [];
        // Current admission year at the top, descending.
        final sorted = List<StudentModel>.from(students)
          ..sort((a, b) {
            final byYear = b.admissionYear.compareTo(a.admissionYear);
            return byYear != 0
                ? byYear
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        if (sorted.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No students yet.\nAdd students before recording receipts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return StreamBuilder<List<ReceiptModel>>(
          stream: feesService.watchAllReceipts(),
          builder: (context, receiptSnap) {
            final receipts = receiptSnap.data ?? [];
            final paidByStudent = <String, double>{};
            for (final r in receipts) {
              paidByStudent[r.studentId] =
                  (paidByStudent[r.studentId] ?? 0) + r.amount;
            }
            final isNarrow = MediaQuery.of(context).size.width < 600;
            if (isNarrow) {
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _StudentCard(
                  student: sorted[i],
                  paid: paidByStudent[sorted[i].id] ?? 0,
                  onTap: () => onOpen(sorted[i]),
                  money: _money,
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                _header(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (_, i) {
                      final s = sorted[i];
                      final paid = paidByStudent[s.id] ?? 0;
                      final pending =
                          (s.totalFees - paid).clamp(0.0, double.infinity);
                      return InkWell(
                        onTap: () => onOpen(s),
                        child: Container(
                          color: i.isEven
                              ? Colors.white
                              : Colors.grey.shade50,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                s.rollNo.isEmpty ? '—' : s.rollNo,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(s.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('${s.admissionYear}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(_money(s.totalFees),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(_money(paid),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                _money(pending),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: pending > 0
                                        ? Colors.red.shade700
                                        : const Color(0xFF2E7D32)),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _header() {
    const style = TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A3C6E),
        fontSize: 13);
    return Container(
      color: const Color(0xFF1A3C6E).withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: const [
        Expanded(flex: 1, child: Text('Roll No', style: style)),
        Expanded(flex: 3, child: Text('Name', style: style)),
        Expanded(flex: 1, child: Text('Year', style: style)),
        Expanded(flex: 1, child: Text('Total', style: style)),
        Expanded(flex: 1, child: Text('Paid', style: style)),
        Expanded(flex: 1, child: Text('Pending', style: style)),
      ]),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final double paid;
  final VoidCallback onTap;
  final String Function(double) money;

  const _StudentCard({
    required this.student,
    required this.paid,
    required this.onTap,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final pending = (student.totalFees - paid).clamp(0.0, double.infinity);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${student.course} • ${student.college} • '
                      '${student.admissionYear}'
                      '${student.rollNo.isNotEmpty ? ' • Roll ${student.rollNo}' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(paid),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32))),
              Text(
                pending > 0
                    ? 'Pending ${money(pending)}'
                    : 'No pending',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: pending > 0
                        ? Colors.red.shade700
                        : const Color(0xFF2E7D32)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Receipts tab ─────────────────────────────────────────────────────────────

class _ReceiptsTab extends StatelessWidget {
  final FirebaseFeesService service;

  const _ReceiptsTab({required this.service});

  String _money(double v) => '₹${v.toStringAsFixed(0)}';

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReceiptModel>>(
      stream: service.watchAllReceipts(),
      builder: (context, snap) {
        final receipts = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting &&
            receipts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (receipts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No receipts yet.\nUse Add Receipt to record one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: receipts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final r = receipts[i];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                if (r.photoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      r.photoUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3C6E)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        size: 20, color: Color(0xFF1A3C6E)),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.receiptNumber.isNotEmpty
                              ? 'Receipt ${r.receiptNumber} — ${r.studentName}'
                              : r.studentName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${r.course} • ${r.college} • ${r.admissionYear}'
                          '${r.rollNo.isNotEmpty ? ' • Roll ${r.rollNo}' : ''}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Text(
                          '${_fmtDateTime(r.createdAt)}  •  ${r.mode}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ]),
                ),
                Text(_money(r.amount),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32))),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Logs tab ─────────────────────────────────────────────────────────────────

class _LogsTab extends StatelessWidget {
  final FirebaseFeesService service;

  const _LogsTab({required this.service});

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReceiptLog>>(
      stream: service.watchAllLogs(),
      builder: (context, snap) {
        final logs = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting && logs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (logs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No receipt activity yet.',
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
          itemBuilder: (_, i) {
            final log = logs[i];
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
                  const Icon(Icons.receipt_long_outlined,
                      size: 18, color: Color(0xFF1A3C6E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RECEIPT — ${log.studentName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          if (log.detail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(log.detail,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${_fmtDateTime(log.timestamp)}  •  by ${log.changedBy}',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ]),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
