import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../student_management/models/student_model.dart';
import '../models/receipt_model.dart';
import '../repositories/fees_repository.dart';
import '../services/firebase_fees_service.dart';

/// Fees view for one student: original fees at creation, each receipt, and
/// the current pending amount per fee type.
class StudentFeesDetailScreen extends StatelessWidget {
  final StudentModel student;

  const StudentFeesDetailScreen({super.key, required this.student});

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _money(double v) => '₹${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final service = FirebaseFeesService();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Student Fees')),
      body: StreamBuilder<List<ReceiptModel>>(
        stream: service.watchAllReceipts(),
        builder: (context, snap) {
          final receipts = (snap.data ?? [])
              .where((r) => r.studentId == student.id)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final pending = FeesCalc.pendingByType(student.fees, receipts);
          final pendingTotal = FeesCalc.pendingTotal(student.fees, receipts);
          final paidTotal = FeesCalc.paidTotal(receipts);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Student header
              _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          backgroundColor:
                              const Color(0xFF1A3C6E).withValues(alpha: 0.12),
                          child: Text(
                            student.name.isEmpty
                                ? '?'
                                : student.name.characters.first.toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF1A3C6E),
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                                Text(
                                  '${student.course}  •  ${student.college}  •  '
                                  'Admitted ${student.admissionYear}'
                                  '${student.rollNo.isNotEmpty ? '  •  Roll ${student.rollNo}' : ''}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ]),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        _stat('Total', _money(student.totalFees),
                            Colors.grey.shade800),
                        _stat('Paid', _money(paidTotal),
                            const Color(0xFF2E7D32)),
                        _stat('Pending', _money(pendingTotal),
                            pendingTotal > 0
                                ? Colors.red.shade700
                                : const Color(0xFF2E7D32)),
                      ]),
                    ]),
              ),
              const SizedBox(height: 12),

              // Original vs pending — one row per fee type.
              _sectionTitle('Original vs Pending'),
              _card(
                child: student.fees.isEmpty && student.originalFees.isEmpty
                    ? Text('No fees were set for this student.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500))
                    : Column(children: [
                        // Fee types: current fees first, then any types that
                        // only existed at creation.
                        for (final t in _feeTypes())
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Expanded(
                                  child: Text(t,
                                      style: const TextStyle(fontSize: 13))),
                              Text(_money(_originalFor(t)),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
                              const SizedBox(width: 18),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  _money(pending[t] ?? 0),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: (pending[t] ?? 0) > 0
                                          ? Colors.red.shade700
                                          : const Color(0xFF2E7D32)),
                                ),
                              ),
                            ]),
                          ),
                        const Divider(height: 12),
                        Row(children: [
                          const Expanded(
                              child: Text('Total',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700))),
                          Text(_money(student.totalFees),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700)),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 70,
                            child: Text(
                              _money(pendingTotal),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: pendingTotal > 0
                                      ? Colors.red.shade700
                                      : const Color(0xFF2E7D32)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Expanded(
                              child: Text('Original (at creation)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey))),
                          const Text('Pending',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ]),
                      ]),
              ),
              const SizedBox(height: 12),

              // Receipts
              _sectionTitle('Receipts (${receipts.length})'),
              if (receipts.isEmpty)
                _card(
                  child: Text('No receipts yet for this student.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                )
              else
                for (final r in receipts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _card(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.receipt_long_outlined,
                                  size: 18, color: Color(0xFF1A3C6E)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.receiptNumber.isNotEmpty
                                      ? 'Receipt ${r.receiptNumber}'
                                      : 'Receipt',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                              ),
                              Text(_money(r.amount),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2E7D32))),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              '${_fmtDateTime(r.createdAt)}  •  ${r.mode}'
                              '${r.createdBy.isNotEmpty ? '  •  by ${r.createdBy}' : ''}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                            if (r.allocations.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(spacing: 8, runSpacing: 3, children: [
                                for (final a in r.allocations)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A3C6E)
                                          .withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${a.type}: ${_money(a.amount)}',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A3C6E)),
                                    ),
                                  ),
                              ]),
                            ],
                            if (r.photoUrl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _openPhoto(context, r.photoUrl),
                                borderRadius: BorderRadius.circular(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    r.photoUrl,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Tap photo to open it',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic)),
                            ],
                          ]),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF1A3C6E))),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
    );
  }

  /// Fee types to show: current fees first, then any types that only
  /// existed in the creation snapshot.
  List<String> _feeTypes() {
    final types = <String>[];
    for (final f in student.fees) {
      if (!types.contains(f.type)) types.add(f.type);
    }
    for (final f in student.originalFees) {
      if (!types.contains(f.type)) types.add(f.type);
    }
    return types;
  }

  double _originalFor(String type) {
    for (final f in student.originalFees) {
      if (f.type == type) return f.amount;
    }
    return 0;
  }

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
}
