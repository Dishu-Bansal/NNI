import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../access/app_session.dart';
import '../../access/session_service.dart';
import '../models/staff_model.dart';
import '../services/firebase_staff_service.dart';
import 'staff_form_screen.dart';

/// Read-only detail view for one staff record: profile header, grouped
/// sections with tappable document links, and a per-staff audit log tab.
/// Ported from gd_college's StaffDetailScreen.
class StaffDetailScreen extends StatefulWidget {
  final StaffModel staff;

  const StaffDetailScreen({super.key, required this.staff});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _service = FirebaseStaffService();
  final _sessionService = SessionService();
  late final Stream<AppSession?> _sessionStream =
      _sessionService.watchSession();

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

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    return StreamBuilder<AppSession?>(
      stream: _sessionStream,
      builder: (context, snap) {
        // While the session loads, assume salary is hidden (fail closed);
        // the staff list already gated entry to this screen.
        final canViewSalary = snap.data?.canViewStaffSalary ?? false;
        return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(
          staff.name.isEmpty ? 'Staff Details' : staff.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          // The edit form exposes salary, so it is hidden together with
          // the salary fields when the viewer may not see salary.
          if (canViewSalary)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StaffFormScreen(existing: staff),
                  ),
                );
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.person_outlined, size: 18), text: 'Details'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DetailsTab(staff: staff, canViewSalary: canViewSalary),
          if (staff.id != null)
            _StaffLogTab(service: _service, staffId: staff.id!)
          else
            const Center(child: Text('Staff record not yet saved')),
        ],
      ),
    );
      },
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final StaffModel staff;
  final bool canViewSalary;

  const _DetailsTab({required this.staff, required this.canViewSalary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeaderCard(staff: staff),
        const SizedBox(height: 12),
        _DetailCard(
          title: 'Personal Information',
          icon: Icons.person_outline,
          fields: [
            _Field("Father's Name", staff.fatherName),
            _Field("Mother's Name", staff.motherName),
            _Field(
                'Date of Birth',
                staff.dob != null
                    ? '${staff.dob!.day.toString().padLeft(2, '0')}/'
                        '${staff.dob!.month.toString().padLeft(2, '0')}/'
                        '${staff.dob!.year}'
                    : null),
            _Field('Gender', staff.gender),
            _Field('Caste', staff.caste),
          ],
        ),
        _DetailCard(
          title: 'Address & Contact',
          icon: Icons.location_on_outlined,
          fields: [
            _Field('Address', staff.address),
            _Field('Village / Town', staff.village),
            _Field('District', staff.district),
            _Field('State', staff.state),
            _Field('PIN Code', staff.pin),
            _Field('Mobile No. 1', staff.mobileNo1),
            _Field('Mobile No. 2', staff.mobileNo2),
          ],
        ),
        _DetailCard(
          title: 'Identity & Certificates',
          icon: Icons.badge_outlined,
          fields: [
            _Field('Aadhar Number', staff.aadharNumber),
            _Field('PAN Card', staff.panCard),
            _Field('Family ID', staff.familyId),
          ],
          fileUrls: {
            'Aadhar Card': staff.aadharUrl,
            'PAN Card': staff.panUrl,
            'SC Certificate': staff.scCertificateUrl,
            'BC Certificate': staff.bcCertificateUrl,
          },
        ),
        _DetailCard(
          title: 'Education',
          icon: Icons.school_outlined,
          fields: const [],
          fileUrls: {
            '10th Certificate': staff.tenthUrl,
            '12th Certificate': staff.twelfthUrl,
            'Graduation': staff.graduationUrl,
            'Post-Graduation': staff.postGraduationUrl,
            'Diploma': staff.diplomaUrl,
            'NET': staff.netUrl,
            'PhD': staff.phdUrl,
          },
        ),
        _DetailCard(
          title: 'Employment',
          icon: Icons.work_outline,
          fields: [
            _Field('Staff ID', staff.staffId),
            _Field('Designation', staff.designation),
            _Field('Course', staff.course),
            _Field('Category', staff.resolvedGroup.label),
            if (canViewSalary) _Field('Salary', staff.salary),
            _Field(
                'Date of Joining',
                staff.dateOfJoining != null
                    ? '${staff.dateOfJoining!.day.toString().padLeft(2, '0')}/'
                        '${staff.dateOfJoining!.month.toString().padLeft(2, '0')}/'
                        '${staff.dateOfJoining!.year}'
                    : null),
            _Field(
                'Date of Relieving',
                staff.dateOfRelieving != null
                    ? '${staff.dateOfRelieving!.day.toString().padLeft(2, '0')}/'
                        '${staff.dateOfRelieving!.month.toString().padLeft(2, '0')}/'
                        '${staff.dateOfRelieving!.year}'
                    : null),
            if (canViewSalary)
              for (var i = 0; i < staff.increments.length; i++)
                _Field(
                  'Increment ${i + 1}',
                staff.increments[i].amount.isEmpty &&
                        staff.increments[i].date == null
                    ? null
                    : '${staff.increments[i].amount.isEmpty ? '—' : '₹${staff.increments[i].amount}'}'
                        '${staff.increments[i].date != null ? ' • ${staff.increments[i].date!.day.toString().padLeft(2, '0')}/${staff.increments[i].date!.month.toString().padLeft(2, '0')}/${staff.increments[i].date!.year}' : ''}',
              ),
          ],
          fileUrls: {
            'Appointment Letter': staff.appointmentLetterUrl,
            'Joining Letter': staff.joiningLetterUrl,
            'University Approval': staff.universityApprovalUrl,
            'Resignation Letter': staff.resignationLetterUrl,
            for (var i = 0; i < staff.experienceCertificateUrls.length; i++)
              'Experience ${i + 1}': staff.experienceCertificateUrls[i],
            for (var i = 0; i < staff.otherFileUrls.length; i++)
              'File ${i + 1}': staff.otherFileUrls[i],
          },
        ),
        _MetadataCard(staff: staff),
      ],
    );
  }
}

class _Field {
  final String label;
  final String? value;

  _Field(this.label, String? raw)
      : value = (raw == null || raw.trim().isEmpty) ? null : raw.trim();
}

class _HeaderCard extends StatelessWidget {
  final StaffModel staff;

  const _HeaderCard({required this.staff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipOval(
            child: staff.photoUrl.isNotEmpty
                ? Image.network(
                    staff.photoUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallback(),
                  )
                : _fallback(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name.isEmpty ? '(no name)' : staff.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _Chip(staff.resolvedGroup.label),
                  if (staff.course.isNotEmpty) _Chip(staff.course),
                ]),
                if (staff.designation.isNotEmpty ||
                    staff.staffId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${staff.designation}${staff.designation.isNotEmpty && staff.staffId.isNotEmpty ? ' • ' : ''}${staff.staffId.isNotEmpty ? 'ID ${staff.staffId}' : ''}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFF1A3C6E).withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: const Icon(Icons.person,
          size: 32, color: Color(0xFF1A3C6E)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C6E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF1A3C6E).withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A3C6E))),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_Field> fields;
  final Map<String, String> fileUrls;

  const _DetailCard({
    required this.title,
    required this.icon,
    this.fields = const [],
    this.fileUrls = const {},
  });

  @override
  Widget build(BuildContext context) {
    final visible = fields.where((f) => f.value != null).toList();
    final files = fileUrls.entries
        .where((e) => e.value.trim().isNotEmpty)
        .toList();
    if (visible.isEmpty && files.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: const Color(0xFF1A3C6E)),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          for (final f in visible) _FieldRow(field: f),
          for (final f in files) _FileRow(label: f.key, url: f.value),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final _Field field;

  const _FieldRow({required this.field});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(field.label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            flex: 3,
            child: Text(field.value ?? '',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final String label;
  final String url;

  const _FileRow({required this.label, required this.url});

  Future<void> _open(BuildContext context) async {
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = RegExp(r'\.(png|jpe?g|gif|webp)(\?|$)').hasMatch(
      url.toLowerCase(),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  url,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.insert_drive_file_outlined,
                        size: 18),
                  ),
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3C6E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.insert_drive_file_outlined,
                    size: 18, color: Color(0xFF1A3C6E)),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A3C6E))),
            ),
            const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  final StaffModel staff;

  const _MetadataCard({required this.staff});

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime? d) => d == null
        ? '—'
        : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year} '
            '${d.hour.toString().padLeft(2, '0')}:'
            '${d.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline,
                size: 18, color: Color(0xFF1A3C6E)),
            SizedBox(width: 8),
            Text('Record Info',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          _MetaRow('Created', '${fmt(staff.createdAt)}'
              '${(staff.createdBy ?? '').isNotEmpty ? ' • by ${staff.createdBy}' : ''}'),
          _MetaRow('Last updated', '${fmt(staff.updatedAt)}'
              '${(staff.lastUpdatedBy ?? '').isNotEmpty ? ' • by ${staff.lastUpdatedBy}' : ''}'),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _StaffLogTab extends StatelessWidget {
  final FirebaseStaffService service;
  final String staffId;

  const _StaffLogTab({required this.service, required this.staffId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffLog>>(
      stream: service.watchLogsFor(staffId),
      builder: (context, snap) {
        final logs = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting &&
            logs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (logs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No activity for this staff yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
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
                  '${log.timestamp.day.toString().padLeft(2, '0')}/'
                  '${log.timestamp.month.toString().padLeft(2, '0')}/'
                  '${log.timestamp.year}  '
                  '${log.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${log.timestamp.minute.toString().padLeft(2, '0')}'
                  '  •  by ${log.changedBy}',
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
}
