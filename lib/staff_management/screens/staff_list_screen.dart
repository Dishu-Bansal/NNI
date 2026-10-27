import 'package:flutter/material.dart';

import '../../access/app_session.dart';
import '../../access/session_service.dart';
import '../../access/widgets/no_access_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/pagination_bar.dart';
import '../models/staff_model.dart';
import '../services/firebase_staff_service.dart';
import 'staff_detail_screen.dart';
import 'staff_form_screen.dart';

/// Staff Management: staff table/cards with search, group/course filters
/// and sorting, plus an audit-log tab. Ported from gd_college's Staff page
/// and restyled to match NNI's student list.
class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirebaseStaffService();
  final _sessionService = SessionService();
  late final Stream<AppSession?> _sessionStream =
      _sessionService.watchSession();
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

  void _openForm([StaffModel? staff]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffFormScreen(existing: staff),
      ),
    );
  }

  void _openDetail(StaffModel staff) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StaffDetailScreen(staff: staff)),
    );
  }

  Future<void> _delete(StaffModel staff) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete'),
        content:
            Text('Delete "${staff.name}"? This cannot be undone.'),
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
      await _service.delete(staff.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${staff.name} deleted')),
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
    return StreamBuilder<AppSession?>(
      stream: _sessionStream,
      builder: (context, snap) {
        final session = snap.data;
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (session == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        if (!session.canAccessStaff) {
          return noAccessScaffold(
              module: 'Staff Management', drawer: const AppDrawer());
        }
        return _content(canEdit: session.canViewStaffSalary);
      },
    );
  }

  Widget _content({required bool canEdit}) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final showAdd = _tabs.index == 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Staff Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (isNarrow && showAdd)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Staff',
              onPressed: () => _openForm(),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Staff'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _StaffTab(
            service: _service,
            canEdit: canEdit,
            onAdd: () => _openForm(),
            onEdit: _openForm,
            onDelete: _delete,
            onOpen: _openDetail,
          ),
          _LogsTab(service: _service),
        ],
      ),
      floatingActionButton: !isNarrow && showAdd
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: const Color(0xFF1A3C6E),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Staff',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

// ── Staff tab ────────────────────────────────────────────────────────────────

class _StaffTab extends StatefulWidget {
  final FirebaseStaffService service;
  final bool canEdit;
  final VoidCallback onAdd;
  final void Function(StaffModel?) onEdit;
  final void Function(StaffModel) onDelete;
  final void Function(StaffModel) onOpen;

  const _StaffTab({
    required this.service,
    required this.canEdit,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  static const _pageSize = 10;

  final _searchCtrl = TextEditingController();

  StaffGroup? _groupFilter;
  String? _courseFilter;

  int _page = 1;

  // 0 = name, 1 = designation, 2 = course, 3 = joining
  int _sortCol = 0;
  bool _sortAsc = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _searchCtrl.text.trim().isNotEmpty ||
      _groupFilter != null ||
      _courseFilter != null;

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _groupFilter = null;
      _courseFilter = null;
      _page = 1;
    });
  }

  List<StaffModel> _applyFiltersAndSort(List<StaffModel> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = all.where((s) {
      if (q.isNotEmpty) {
        final hay =
            '${s.name} ${s.fatherName} ${s.staffId} ${s.mobileNo1}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (_groupFilter != null && s.resolvedGroup != _groupFilter) {
        return false;
      }
      if (_courseFilter != null && s.course != _courseFilter) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 1:
          cmp = a.designation.toLowerCase().compareTo(
                b.designation.toLowerCase(),
              );
          break;
        case 2:
          cmp = a.course.compareTo(b.course);
          break;
        case 3:
          final ad = a.dateOfJoining;
          final bd = b.dateOfJoining;
          if (ad == null && bd == null) {
            cmp = 0;
          } else if (ad == null) {
            cmp = 1;
          } else if (bd == null) {
            cmp = -1;
          } else {
            cmp = ad.compareTo(bd);
          }
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
    return StreamBuilder<List<StaffModel>>(
      stream: widget.service.watchAll(),
      builder: (context, snap) {
        final staff = snap.data ?? [];
        final loading =
            snap.connectionState == ConnectionState.waiting && staff.isEmpty;
        final filtered = _applyFiltersAndSort(staff);
        final totalPages =
            filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
        final page =
            _page < 1 ? 1 : (_page > totalPages ? totalPages : _page);
        final start = (page - 1) * _pageSize;
        final slice = filtered.isEmpty
            ? const <StaffModel>[]
            : filtered.sublist(
                start, (start + _pageSize).clamp(0, filtered.length));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() => _page = 1),
                decoration: InputDecoration(
                  hintText: 'Search by name, staff ID, mobile',
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
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chipRow('Group', [
                    _chip('All', _groupFilter == null, () => setState(() {
                          _groupFilter = null;
                          _page = 1;
                        })),
                    for (final g in StaffGroup.values)
                      _chip(g.label, _groupFilter == g, () => setState(() {
                            _groupFilter = g;
                            _page = 1;
                          })),
                  ]),
                  _chipRow('Course', [
                    _chip('All', _courseFilter == null,
                        () => setState(() {
                              _courseFilter = null;
                              _page = 1;
                            })),
                    for (final c in StaffModel.courses)
                      _chip(c, _courseFilter == c, () => setState(() {
                            _courseFilter = c;
                            _page = 1;
                          })),
                  ]),
                ],
              ),
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
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : staff.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'No staff yet.\nTap Add Staff to create the first record.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: widget.onAdd,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Staff'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No staff match your filters.',
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
                                  itemBuilder: (_, i) => _StaffCard(
                                    staff: slice[i],
                                    canEdit: widget.canEdit,
                                    onOpen: () => widget.onOpen(slice[i]),
                                    onEdit: () => widget.onEdit(slice[i]),
                                    onDelete: () =>
                                        widget.onDelete(slice[i]),
                                    initial: _initial(slice[i].name),
                                  ),
                                )
                              : _StaffTable(
                                  staff: slice,
                                  canEdit: widget.canEdit,
                                  sortColumnIndex: _sortCol,
                                  sortAscending: _sortAsc,
                                  onSort: _onSort,
                                  onOpen: widget.onOpen,
                                  onEdit: widget.onEdit,
                                  onDelete: widget.onDelete,
                                  initialOf: _initial,
                                ),
            ),
            if (staff.isNotEmpty)
              PaginationBar(
                currentPage: page,
                totalPages: totalPages,
                totalCount: filtered.length,
                pageSize: _pageSize,
                onPageChanged: (p) => setState(() => _page = p),
              ),
          ],
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
}

// ── Table (wide screens) ─────────────────────────────────────────────────────

class _StaffTable extends StatelessWidget {
  final List<StaffModel> staff;
  final bool canEdit;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int) onSort;
  final void Function(StaffModel) onOpen;
  final void Function(StaffModel?) onEdit;
  final void Function(StaffModel) onDelete;
  final String Function(String) initialOf;

  const _StaffTable({
    required this.staff,
    required this.canEdit,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onOpen,
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
            itemCount: staff.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (_, i) => _TableRow(
              staff: staff[i],
              canEdit: canEdit,
              isEven: i.isEven,
              initial: initialOf(staff[i].name),
              onOpen: () => onOpen(staff[i]),
              onEdit: () => onEdit(staff[i]),
              onDelete: () => onDelete(staff[i]),
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
          child: Text('Staff ID',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3C6E),
                  fontSize: 13)),
        ),
        _HeaderCell('Designation', 2, 1, sortColumnIndex, sortAscending,
            onSort),
        _HeaderCell(
            'Course', 2, 2, sortColumnIndex, sortAscending, onSort),
        _HeaderCell(
            'Joined', 2, 3, sortColumnIndex, sortAscending, onSort),
        const Expanded(
          flex: 1,
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
  final StaffModel staff;
  final bool canEdit;
  final bool isEven;
  final String initial;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableRow({
    required this.staff,
    required this.canEdit,
    required this.isEven,
    required this.initial,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Container(
        color: isEven ? Colors.white : Colors.grey.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Expanded(
            flex: 4,
            child: Row(children: [
              ClipOval(child: _avatar(initial, 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '${staff.resolvedGroup.label}'
                      '${staff.course.isNotEmpty ? ' • ${staff.course}' : ''}',
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
            child: Text(
              staff.staffId.isEmpty ? '—' : staff.staffId,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              staff.designation.isEmpty ? '—' : staff.designation,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              staff.course.isEmpty ? '—' : staff.course,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              staff.dateOfJoining == null
                  ? '—'
                  : '${staff.dateOfJoining!.day.toString().padLeft(2, '0')}/'
                      '${staff.dateOfJoining!.month.toString().padLeft(2, '0')}/'
                      '${staff.dateOfJoining!.year}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(children: [
              if (canEdit)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: Color(0xFF1A3C6E)),
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
      ),
    );
  }

  Widget _avatar(String initial, double size) {
    return Container(
      width: size,
      height: size,
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

// ── Mobile card ──────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final StaffModel staff;
  final bool canEdit;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String initial;

  const _StaffCard({
    required this.staff,
    required this.canEdit,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipOval(
              child: staff.photoUrl.isNotEmpty
                  ? Image.network(
                      staff.photoUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _avatar(),
                    )
                  : _avatar(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Wrap(spacing: 6, runSpacing: 3, children: [
                    _tag(staff.resolvedGroup.label),
                    if (staff.course.isNotEmpty) _tag(staff.course),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    '${staff.designation.isNotEmpty ? '${staff.designation}  •  ' : ''}'
                    '${staff.staffId.isNotEmpty ? 'ID ${staff.staffId}  •  ' : ''}'
                    '${staff.mobileNo1.isNotEmpty ? staff.mobileNo1 : 'No mobile'}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                if (canEdit)
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

  Widget _avatar() {
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

  Widget _tag(String text) {
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
  final FirebaseStaffService service;

  const _LogsTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffLog>>(
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
                'No activity yet.\nStaff changes will be recorded here.',
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
  final StaffLog log;

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
                  '${log.action.toUpperCase()} — ${log.staffName}',
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
