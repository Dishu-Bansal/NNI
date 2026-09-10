import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../fees/screens/student_fees_detail_screen.dart';
import '../models/student_model.dart';
import 'student_form_screen.dart';

/// Read-only view of one student, opened from the student list's View action.
/// Layout follows the gd_college student detail screen: a header card, then
/// collapsible section cards of label/value rows, and a metadata card.
class StudentDetailScreen extends StatelessWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(student.name.isEmpty ? 'Student Details' : student.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => StudentFormScreen(existing: student)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(student: student),
          const SizedBox(height: 12),
          _DetailCard(
            title: 'Personal Information',
            icon: Icons.person_outline,
            fields: [
              _Field('Full Name', student.name),
              _Field("Father's Name", student.fathersName),
              _Field("Mother's Name", student.mothersName),
              _Field('Date of Birth', _fmtDate(student.dateOfBirth)),
              _Field('Address', student.address),
            ],
          ),
          _DetailCard(
            title: 'Identification',
            icon: Icons.badge_outlined,
            fields: [
              _Field('HNMC No.', student.hnmcNo),
              _Field('Registration No.', student.registrationNo),
              _Field('Roll No.', student.rollNo),
              _Field('Family ID', student.familyId),
              _Field('Aadhar Number', _maskAadhar(student.aadharNo)),
              _Field('Bank Account No.', student.bankAccountNo),
            ],
          ),
          _DetailCard(
            title: 'Contact',
            icon: Icons.phone_outlined,
            phones: [
              _Field('Primary Phone', student.primaryPhone),
              _Field("Father's Phone", student.fathersPhone),
              _Field('Alternate Phone', student.alternatePhone),
            ],
          ),
          _DetailCard(
            title: 'Course & Fees',
            icon: Icons.menu_book_outlined,
            fields: [
              _Field('Course', student.course),
              _Field('College', student.college),
              _Field(
                  'Admission Year',
                  student.admissionYear == 0
                      ? null
                      : '${student.admissionYear}'),
              for (final f in student.fees)
                _Field(
                  f.type.trim().isEmpty ? 'Fee' : f.type.trim(),
                  f.comment.trim().isEmpty
                      ? _money(f.amount)
                      : '${_money(f.amount)}  (${f.comment.trim()})',
                ),
              _Field('Total Fees', _money(student.totalFees)),
            ],
            action: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        StudentFeesDetailScreen(student: student)),
              ),
              icon: const Icon(Icons.receipt_long_outlined, size: 16),
              label: const Text('View fees & receipts'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A3C6E),
              ),
            ),
          ),
          _MetadataCard(student: student),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Formatting helpers ───────────────────────────────────────────────────────

String _fmtDate(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _money(double v) => '₹${v.toStringAsFixed(0)}';

String _maskAadhar(String n) {
  final digits = n.trim();
  if (digits.length < 4) return digits;
  return 'XXXX XXXX ${digits.substring(digits.length - 4)}';
}

String _fmtDateTime(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ── Field model ──────────────────────────────────────────────────────────────

class _Field {
  final String label;
  final String? value;

  const _Field(this.label, this.value);
}

// ── Header card ──────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final StudentModel student;

  const _HeaderCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: student.photoUrl.isNotEmpty
                ? Image.network(student.photoUrl,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _avatar())
                : _avatar(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name.isEmpty ? 'Unknown Student' : student.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (student.course.isNotEmpty)
                    _Chip(student.course, const Color(0xFF1A3C6E)),
                  if (student.college.isNotEmpty)
                    _Chip(student.college, Colors.teal),
                  if (student.admissionYear > 0)
                    _Chip('Batch ${student.admissionYear}',
                        Colors.amber.shade800),
                  if (student.rollNo.isNotEmpty)
                    _Chip('Roll ${student.rollNo}', Colors.indigo),
                  if (student.hnmcNo.isNotEmpty)
                    _Chip('HNMC ${student.hnmcNo}', Colors.deepPurple),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 84,
      height: 84,
      color: const Color(0xFF1A3C6E).withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        student.name.trim().isEmpty
            ? '?'
            : student.name.trim().characters.first.toUpperCase(),
        style: const TextStyle(
            color: Color(0xFF1A3C6E),
            fontWeight: FontWeight.w700,
            fontSize: 30),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

class _DetailCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<_Field> fields;
  final List<_Field> phones;
  final Widget? action;

  const _DetailCard({
    required this.title,
    required this.icon,
    this.fields = const [],
    this.phones = const [],
    this.action,
  });

  @override
  State<_DetailCard> createState() => _DetailCardState();
}

class _DetailCardState extends State<_DetailCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    // Every row is rendered even when empty: a missing value shows as '—'
    // instead of hiding the row.
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3C6E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon,
                    size: 16, color: const Color(0xFF1A3C6E)),
              ),
              const SizedBox(width: 10),
              Text(widget.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A3C6E))),
              const Spacer(),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey, size: 20),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(children: [
              for (final f in widget.fields) _FieldRow(f.label, f.value),
              for (final p in widget.phones) _PhoneRow(p.label, p.value),
              if (widget.action != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: widget.action,
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String? value;

  const _FieldRow(this.label, this.value);

  bool get _isEmpty => value == null || value!.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _isEmpty ? '—' : value!.trim(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _isEmpty ? Colors.grey.shade400 : null,
            ),
          ),
        ),
      ]),
    );
  }
}

/// A phone row: same shape as a field row plus a tap-to-call button.
class _PhoneRow extends StatelessWidget {
  final String label;
  final String? value;

  const _PhoneRow(this.label, this.value);

  bool get _isEmpty => value == null || value!.trim().isEmpty;

  Future<void> _call(BuildContext context) async {
    final target = value!.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    try {
      await launchUrl(Uri.parse('tel:$target'));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start the call: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _isEmpty ? '—' : value!.trim(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _isEmpty ? Colors.grey.shade400 : null,
            ),
          ),
        ),
        if (!_isEmpty)
          IconButton(
            onPressed: () => _call(context),
            icon: const Icon(Icons.call_outlined, size: 18),
            tooltip: 'Call',
            color: const Color(0xFF1A3C6E),
            visualDensity: VisualDensity.compact,
          ),
      ]),
    );
  }
}

// ── Metadata card ────────────────────────────────────────────────────────────

class _MetadataCard extends StatelessWidget {
  final StudentModel student;

  const _MetadataCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record Metadata',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _MetaRow('Doc ID', student.id ?? '—'),
            if (student.createdAt != null)
              _MetaRow('Created', _fmtDateTime(student.createdAt!)),
            if (student.updatedAt != null)
              _MetaRow('Updated', _fmtDateTime(student.updatedAt!)),
            if ((student.createdBy ?? '').isNotEmpty)
              _MetaRow('Created by', student.createdBy!),
            if ((student.lastUpdatedBy ?? '').isNotEmpty)
              _MetaRow('Last update by', student.lastUpdatedBy!),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
