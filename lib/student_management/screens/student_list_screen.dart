import 'package:flutter/material.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/pagination_bar.dart';
import '../models/student_model.dart';
import '../services/firebase_student_service.dart';
import 'student_detail_screen.dart';
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

  void _openDetail(StudentModel student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDetailScreen(student: student),
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
      drawer: appDrawer(context),
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
          _StudentsTab(
            service: _service,
            onView: _openDetail,
            onEdit: _openForm,
            onDelete: _delete,
          ),
          _LogsTab(service: _service),
        ],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: const Color(0xFF1A3C6E),
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

class _StudentsTab extends StatefulWidget {
  final FirebaseStudentService service;
  final void Function(StudentModel) onView;
  final void Function(StudentModel?) onEdit;
  final void Function(StudentModel) onDelete;

  const _StudentsTab({
    required this.service,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  static const _pageSize = 10;

  final _searchCtrl = TextEditingController();

  /// null means "all".
  String? _courseFilter;
  String? _collegeFilter;
  int? _yearFilter;

  int _page = 1;

  // 0 = name, 1 = course, 2 = college, 3 = admission year
  int _sortCol = 0;
  bool _sortAsc = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _searchCtrl.text.trim().isNotEmpty ||
      _courseFilter != null ||
      _collegeFilter != null ||
      _yearFilter != null;

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _courseFilter = null;
      _collegeFilter = null;
      _yearFilter = null;
      _page = 1;
    });
  }

  List<StudentModel> _applyFiltersAndSort(List<StudentModel> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = all.where((s) {
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      if (_courseFilter != null && s.course != _courseFilter) return false;
      if (_collegeFilter != null && s.college != _collegeFilter) return false;
      if (_yearFilter != null && s.admissionYear != _yearFilter) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 1:
          cmp = a.course.compareTo(b.course);
          break;
        case 2:
          cmp = a.college.compareTo(b.college);
          break;
        case 3:
          cmp = a.admissionYear.compareTo(b.admissionYear);
          break;
        default:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _onSort(int col) {
    setState(() {
      if (_sortCol == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCol = col;
        _sortAsc = true;
      }
      _page = 1;
    });
  }

  String _initial(String name) =>
      name.isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StudentModel>>(
      stream: widget.service.watchAll(),
      builder: (context, snap) {
        final students = snap.data ?? [];
        final loading =
            snap.connectionState == ConnectionState.waiting && students.isEmpty;
        final filtered = _applyFiltersAndSort(students);
        final years = students.map((s) => s.admissionYear).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
        final totalPages =
            filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
        final page = _page < 1
            ? 1
            : (_page > totalPages ? totalPages : _page);
        final start = (page - 1) * _pageSize;
        final slice = filtered.isEmpty
            ? const <StudentModel>[]
            : filtered.sublist(
                start, (start + _pageSize).clamp(0, filtered.length));

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
                        onPressed: () => _clearFilters(),
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
          // Filter chips — one row per group, left-aligned and each
          // horizontally scrollable when the options are many.
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
                _chip('All', _yearFilter == null, () => setState(() {
                      _yearFilter = null;
                      _page = 1;
                    })),
                for (final y in years)
                  _chip('$y', _yearFilter == y, () => setState(() {
                        _yearFilter = y;
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
          // Table / list
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : students.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No students yet.\nTap Add Student to create the first one.',
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
                                  onView: () => widget.onView(slice[i]),
                                  onEdit: () => widget.onEdit(slice[i]),
                                  onDelete: () => widget.onDelete(slice[i]),
                                  initial: _initial(slice[i].name),
                                ),
                              )
                            : _StudentTable(
                                students: slice,
                                sortColumnIndex: _sortCol,
                                sortAscending: _sortAsc,
                                onSort: _onSort,
                                onView: (s) => widget.onView(s),
                                onEdit: (s) => widget.onEdit(s),
                                onDelete: (s) => widget.onDelete(s),
                                initialOf: _initial,
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

  /// One left-aligned chip group: label + chips in a single horizontally
  /// scrollable row (chips flow off-screen instead of wrapping).
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
}

// ── Table (wide screens) ─────────────────────────────────────────────────────

class _StudentTable extends StatelessWidget {
  final List<StudentModel> students;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int) onSort;
  final void Function(StudentModel) onView;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onDelete;
  final String Function(String) initialOf;

  const _StudentTable({
    required this.students,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.initialOf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        _TableHeader(
          sortColumnIndex: sortColumnIndex,
          sortAscending: sortAscending,
          onSort: onSort,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: students.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (_, i) => _TableRow(
              student: students[i],
              isEven: i.isEven,
              initial: initialOf(students[i].name),
              onView: () => onView(students[i]),
              onEdit: () => onEdit(students[i]),
              onDelete: () => onDelete(students[i]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int) onSort;

  const _TableHeader({
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A3C6E).withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _HeaderCell('Name', 4, 0, sortColumnIndex, sortAscending, onSort),
        const Expanded(
          flex: 1,
          child: Text('Roll No',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3C6E),
                  fontSize: 13)),
        ),
        _HeaderCell('Course', 2, 1, sortColumnIndex, sortAscending, onSort),
        _HeaderCell('College', 2, 2, sortColumnIndex, sortAscending, onSort),
        _HeaderCell('Adm. Year', 1, 3, sortColumnIndex, sortAscending, onSort),
        const Expanded(
          flex: 2,
          child: Text('Fees',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3C6E),
                  fontSize: 13)),
        ),
        const Expanded(
          flex: 2,
          child: Text('Actions',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3C6E),
                  fontSize: 13)),
        ),
      ]),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final int col;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int) onSort;

  const _HeaderCell(this.label, this.flex, this.col, this.sortColumnIndex,
      this.sortAscending, this.onSort);

  @override
  Widget build(BuildContext context) {
    final active = sortColumnIndex == col;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => onSort(col),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3C6E),
                  fontSize: 13)),
          if (active)
            Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: const Color(0xFF1A3C6E)),
        ]),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final StudentModel student;
  final bool isEven;
  final String initial;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableRow({
    required this.student,
    required this.isEven,
    required this.initial,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fees = student.fees;
    return Container(
      color: isEven ? Colors.white : Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Row(children: [
            ClipOval(
              child: student.photoUrl.isNotEmpty
                  ? Image.network(
                      student.photoUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _avatar(initial),
                    )
                  : _avatar(initial),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (student.fathersName.isNotEmpty)
                    Text(
                      'Father: ${student.fathersName}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ]),
        ),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.rollNo.isEmpty ? '—' : student.rollNo,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (student.hnmcNo.isNotEmpty)
                Text(
                  'HNMC: ${student.hnmcNo}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(student.course,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
        ),
        Expanded(
          flex: 2,
          child: Text(student.college,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
        ),
        Expanded(
          flex: 1,
          child: Text('${student.admissionYear}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
        ),
        Expanded(
          flex: 2,
          child: Text(
            fees.isEmpty
                ? '—'
                : '${fees.length}  •  ₹${student.totalFees.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(children: [
            IconButton(
              onPressed: onView,
              icon: const Icon(Icons.visibility_outlined,
                  size: 18, color: Color(0xFF1A3C6E)),
              tooltip: 'View',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: Colors.amber),
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.red),
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _avatar(String initial) {
    return Container(
      width: 28,
      height: 28,
      color: const Color(0xFF1A3C6E).withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              color: Color(0xFF1A3C6E),
              fontWeight: FontWeight.w700,
              fontSize: 12)),
    );
  }
}

// ── Mobile card (narrow screens) ─────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String initial;

  const _StudentCard({
    required this.student,
    required this.onView,
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
                      errorBuilder: (_, _, _) => _avatar(initial),
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
                    '${student.rollNo.isNotEmpty ? 'Roll ${student.rollNo}  •  ' : ''}'
                    '${student.hnmcNo.isNotEmpty ? 'HNMC ${student.hnmcNo}  •  ' : ''}'
                    'Admitted ${student.admissionYear}'
                    '${fees > 0 ? '  •  ${student.fees.length} fee '
                        '${student.fees.length == 1 ? 'entry' : 'entries'}'
                        ' (₹${student.totalFees.toStringAsFixed(0)})' : ''}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (student.fathersName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        'Father: ${student.fathersName}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'view') onView();
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'view',
                    child: Row(children: [
                      Icon(Icons.visibility_outlined,
                          size: 16, color: Color(0xFF1A3C6E)),
                      SizedBox(width: 8),
                      Text('View'),
                    ])),
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
      color: const Color(0xFF1A3C6E).withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              color: Color(0xFF1A3C6E),
              fontWeight: FontWeight.w700,
              fontSize: 18)),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C6E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF1A3C6E).withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A3C6E))),
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
