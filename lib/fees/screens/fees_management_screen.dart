import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../student_management/models/student_model.dart';
import '../../student_management/services/firebase_student_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/pagination_bar.dart';
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
      drawer: appDrawer(context),
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

class _StudentsTab extends StatefulWidget {
  final FirebaseStudentService studentService;
  final FirebaseFeesService feesService;
  final void Function(StudentModel) onOpen;

  const _StudentsTab({
    required this.studentService,
    required this.feesService,
    required this.onOpen,
  });

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  static const _pageSize = 10;

  final _searchCtrl = TextEditingController();

  // Streams are created once per tab. Keystrokes in the search box then only
  // re-filter the already-loaded data instead of re-subscribing to Firestore
  // (which made the list reload on every key press).
  late final Stream<List<StudentModel>> _studentsStream =
      widget.studentService.watchAll();
  late final Stream<List<ReceiptModel>> _receiptsStream =
      widget.feesService.watchAllReceipts();

  /// null means "all".
  String? _courseFilter;
  String? _collegeFilter;
  int? _yearFilter;
  String? _statusFilter; // 'Pending' | 'Paid'

  int _page = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _searchCtrl.text.trim().isNotEmpty ||
      _courseFilter != null ||
      _collegeFilter != null ||
      _yearFilter != null ||
      _statusFilter != null;

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _courseFilter = null;
      _collegeFilter = null;
      _yearFilter = null;
      _statusFilter = null;
      _page = 1;
    });
  }

  String _money(double v) => '₹${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentModel>>(
      stream: _studentsStream,
      builder: (context, studentSnap) {
        if (studentSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final students = studentSnap.data ?? [];
        final years = students.map((s) => s.admissionYear).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
        return StreamBuilder<List<ReceiptModel>>(
          stream: _receiptsStream,
          builder: (context, receiptSnap) {
            final receipts = receiptSnap.data ?? [];
            final paidByStudent = <String, double>{};
            for (final r in receipts) {
              paidByStudent[r.studentId] =
                  (paidByStudent[r.studentId] ?? 0) + r.amount;
            }

            final q = _searchCtrl.text.trim().toLowerCase();
            // Current admission year at the top, descending.
            final filtered = students.where((s) {
              if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) {
                return false;
              }
              if (_courseFilter != null && s.course != _courseFilter) {
                return false;
              }
              if (_collegeFilter != null && s.college != _collegeFilter) {
                return false;
              }
              if (_yearFilter != null && s.admissionYear != _yearFilter) {
                return false;
              }
              if (_statusFilter != null) {
                final pending = (s.totalFees - (paidByStudent[s.id] ?? 0))
                    .clamp(0.0, double.infinity);
                if (_statusFilter == 'Pending' && pending <= 0) return false;
                if (_statusFilter == 'Paid' && pending > 0) return false;
              }
              return true;
            }).toList()
              ..sort((a, b) {
                final byYear = b.admissionYear.compareTo(a.admissionYear);
                return byYear != 0
                    ? byYear
                    : a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

            // Pagination over the filtered set.
            final totalPages =
                filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
            final page = _page < 1 ? 1 : (_page > totalPages ? totalPages : _page);
            final start = (page - 1) * _pageSize;
            final slice = filtered.isEmpty
                ? const <StudentModel>[]
                : filtered.sublist(
                    start, (start + _pageSize).clamp(0, filtered.length));

            // Total pending across the filtered set (reflects the filters).
            final totalPending = filtered.fold(
                0.0,
                (sum, s) =>
                    sum +
                    (s.totalFees - (paidByStudent[s.id] ?? 0))
                        .clamp(0.0, double.infinity));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() => _page = 1),
                  decoration: InputDecoration(
                    hintText: 'Search by name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearFilters,
                          )
                        : null,
                    isDense: true,
                  ),
                ),
              ),
              // Filter chips — one row per group, left-aligned and
              // horizontally scrollable.
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _chipRow('Course', [
                    _chip('All', _courseFilter == null,
                        () => setState(() {
                              _courseFilter = null;
                              _page = 1;
                            })),
                    for (final c in StudentModel.courses)
                      _chip(c, _courseFilter == c, () => setState(() {
                            _courseFilter = c;
                            _page = 1;
                          })),
                  ]),
                  _chipRow('College', [
                    _chip('All', _collegeFilter == null,
                        () => setState(() {
                              _collegeFilter = null;
                              _page = 1;
                            })),
                    for (final c in StudentModel.colleges)
                      _chip(c, _collegeFilter == c, () => setState(() {
                            _collegeFilter = c;
                            _page = 1;
                          })),
                  ]),
                  _chipRow('Year', [
                    _chip('All', _yearFilter == null,
                        () => setState(() {
                              _yearFilter = null;
                              _page = 1;
                            })),
                    for (final y in years)
                      _chip('$y', _yearFilter == y, () => setState(() {
                            _yearFilter = y;
                            _page = 1;
                          })),
                  ]),
                  _chipRow('Status', [
                    _chip('All', _statusFilter == null,
                        () => setState(() {
                              _statusFilter = null;
                              _page = 1;
                            })),
                    _chip('Pending', _statusFilter == 'Pending',
                        () => setState(() {
                              _statusFilter = 'Pending';
                              _page = 1;
                            })),
                    _chip('Paid', _statusFilter == 'Paid',
                        () => setState(() {
                              _statusFilter = 'Paid';
                              _page = 1;
                            })),
                  ]),
                ]),
              ),
              if (_hasFilters)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Clear filters'),
                    ),
                  ),
                ),
              // Total pending summary — reflects the active filters.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3C6E).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            const Color(0xFF1A3C6E).withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.payments_outlined,
                        size: 18, color: Color(0xFF1A3C6E)),
                    const SizedBox(width: 8),
                    Text(
                      'Total Pending Fees'
                      '${filtered.isNotEmpty ? '  •  ${filtered.length} ${filtered.length == 1 ? 'student' : 'students'}' : ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1A3C6E)),
                    ),
                    const Spacer(),
                    Text(
                      '₹${totalPending.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: totalPending > 0
                            ? Colors.red.shade700
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ]),
                ),
              ),
              Expanded(
                child: students.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No students yet.\nAdd students before recording receipts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No students match your filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : MediaQuery.of(context).size.width < 600
                            ? ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: slice.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) => _StudentCard(
                                  student: slice[i],
                                  paid: paidByStudent[slice[i].id] ?? 0,
                                  onTap: () => widget.onOpen(slice[i]),
                                  money: _money,
                                ),
                              )
                            : Container(
                                margin: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(children: [
                                  _header(),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: slice.length,
                                      separatorBuilder: (_, _) => Divider(
                                          height: 1,
                                          color: Colors.grey.shade100),
                                      itemBuilder: (_, i) {
                                        final s = slice[i];
                                        final paid =
                                            paidByStudent[s.id] ?? 0;
                                        final pending = (s.totalFees - paid)
                                            .clamp(0.0, double.infinity);
                                        return InkWell(
                                          onTap: () => widget.onOpen(s),
                                          child: Container(
                                            color: i.isEven
                                                ? Colors.white
                                                : Colors.grey.shade50,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10),
                                            child: Row(children: [
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  s.rollNo.isEmpty
                                                      ? '—'
                                                      : s.rollNo,
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors
                                                          .grey.shade800),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(s.name,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14)),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                    '${s.admissionYear}',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .grey.shade800)),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(_money(
                                                    s.totalFees),
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .grey.shade800)),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(_money(paid),
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Color(
                                                            0xFF2E7D32),
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  _money(pending),
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: pending > 0
                                                          ? Colors.red
                                                              .shade700
                                                          : const Color(
                                                              0xFF2E7D32)),
                                                ),
                                              ),
                                            ]),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ]),
                              ),
              ),
              if (students.isNotEmpty)
                PaginationBar(
                  currentPage: page,
                  totalPages: totalPages,
                  totalCount: filtered.length,
                  pageSize: _pageSize,
                  onPageChanged: (p) => setState(() => _page = p),
                ),
            ]);
          },
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600)),
    );
  }

  Widget _chipRow(String label, List<Widget> chips) {
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          _sectionLabel(label),
          ...chips,
        ]),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selectedColor: const Color(0xFF1A3C6E).withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF1A3C6E) : Colors.grey.shade700,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
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

class _ReceiptsTab extends StatefulWidget {
  final FirebaseFeesService service;

  const _ReceiptsTab({required this.service});

  @override
  State<_ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends State<_ReceiptsTab> {
  late final Stream<List<ReceiptModel>> _receiptsStream =
      widget.service.watchAllReceipts();

  String _money(double v) => '₹${v.toStringAsFixed(0)}';

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _openPhoto(BuildContext context, String url) async {
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open photo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReceiptModel>>(
      stream: _receiptsStream,
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
                  InkWell(
                    onTap: () => _openPhoto(context, r.photoUrl),
                    borderRadius: BorderRadius.circular(6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        r.photoUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 52,
                          height: 52,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 20, color: Colors.grey.shade500),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 52,
                    height: 52,
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

class _LogsTab extends StatefulWidget {
  final FirebaseFeesService service;

  const _LogsTab({required this.service});

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  late final Stream<List<ReceiptLog>> _logsStream =
      widget.service.watchAllLogs();

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReceiptLog>>(
      stream: _logsStream,
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
