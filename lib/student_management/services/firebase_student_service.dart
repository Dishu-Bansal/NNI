import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/student_model.dart';
import '../repositories/student_repository.dart';

class FirebaseStudentService implements StudentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const _collection = 'students';
  static const _logsCollection = 'studentLogs';

  String get _currentUser => FirebaseAuth.instance.currentUser?.email ?? '';

  // ── Students ───────────────────────────────────────────────────────────

  @override
  Stream<List<StudentModel>> watchAll() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                StudentModel.fromFirestore(d.id, d.data()))
            .toList())
        .handleError((_) => <StudentModel>[]);
  }

  @override
  Future<String> create(StudentModel student) async {
    final now = DateTime.now();
    student.createdAt = now;
    student.updatedAt = now;
    student.createdBy = _currentUser;
    student.lastUpdatedBy = _currentUser;
    // Snapshot the fees as the "original fees" for the fees module.
    student.originalFees = List.of(student.fees);
    final ref =
        await _db.collection(_collection).add(student.toFirestore());
    await _writeLog(
      studentId: ref.id,
      student: student,
      action: 'create',
      detail:
          'Created: ${student.name} (${student.course}, ${student.college}, '
          '${student.admissionYear})',
    );
    return ref.id;
  }

  @override
  Future<void> update(String id, StudentModel student) async {
    final oldSnap = await _db.collection(_collection).doc(id).get();
    final oldData = oldSnap.data() ?? {};
    final oldStudent = StudentModel.fromFirestore(id, oldData);

    student.updatedAt = DateTime.now();
    student.lastUpdatedBy = _currentUser;
    await _db.collection(_collection).doc(id).update(student.toFirestore());
    await _writeLog(
      studentId: id,
      student: student,
      action: 'update',
      detail: _buildUpdateDetail(oldStudent, student),
    );
  }

  @override
  Future<void> delete(String id) async {
    final snap = await _db.collection(_collection).doc(id).get();
    final data = snap.data() ?? {};
    final student = StudentModel.fromFirestore(id, data);
    await _db.collection(_collection).doc(id).delete();
    await _writeLog(
      studentId: id,
      student: student,
      action: 'delete',
      detail:
          'Deleted: ${student.name} (${student.course}, ${student.college})',
    );
  }

  // ── Logs ───────────────────────────────────────────────────────────────

  @override
  Stream<List<StudentLog>> watchAllLogs() {
    return _db
        .collection(_logsCollection)
        .orderBy('timestamp', descending: true)
        .limit(300)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StudentLog.fromFirestore(d.id, d.data()))
            .toList())
        .handleError((_) => <StudentLog>[]);
  }

  Future<void> _writeLog({
    required String studentId,
    required StudentModel student,
    required String action,
    required String detail,
  }) async {
    await _db.collection(_logsCollection).add(StudentLog(
      studentId: studentId,
      studentName: student.name,
      action: action,
      changedBy: _currentUser,
      detail: detail,
    ).toFirestore());
  }

  /// Builds a human-readable summary of which fields changed.
  String _buildUpdateDetail(StudentModel old, StudentModel updated) {
    final parts = <String>[];
    void diff(String label, String a, String b) {
      if (a != b) parts.add('$label: $a → $b');
    }

    diff('Name', old.name, updated.name);
    diff('Course', old.course, updated.course);
    diff('College', old.college, updated.college);
    if (old.admissionYear != updated.admissionYear) {
      parts.add('Admission year: ${old.admissionYear} → '
          '${updated.admissionYear}');
    }
    if (old.photoUrl != updated.photoUrl) {
      parts.add('Photo ${old.photoUrl.isEmpty ? 'added' : 'changed'}');
    }
    diff('HNMC No.', old.hnmcNo, updated.hnmcNo);
    diff('Registration No.', old.registrationNo, updated.registrationNo);
    diff("Mother's name", old.mothersName, updated.mothersName);
    diff("Father's name", old.fathersName, updated.fathersName);
    diff('Address', old.address, updated.address);
    if (old.dateOfBirth?.toIso8601String() !=
        updated.dateOfBirth?.toIso8601String()) {
      parts.add('DOB: ${_fmtDate(old.dateOfBirth)} → '
          '${_fmtDate(updated.dateOfBirth)}');
    }
    diff('Family ID', old.familyId, updated.familyId);
    diff('Aadhar No.', old.aadharNo, updated.aadharNo);
    diff('Bank Account No.', old.bankAccountNo, updated.bankAccountNo);

    final oldFees = old.fees.map((f) => '${f.type}:${f.amount}').toList()
      ..sort();
    final newFees =
        updated.fees.map((f) => '${f.type}:${f.amount}').toList()
          ..sort();
    if (oldFees.join('|') != newFees.join('|')) {
      parts.add('Fees updated (${updated.fees.length} entries, '
          'total ₹${updated.totalFees.toStringAsFixed(0)})');
    }

    if (parts.isEmpty) return 'Updated ${updated.name}';
    return 'Updated: ${updated.name} — ${parts.join('; ')}';
  }

  static String _fmtDate(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Photo upload ───────────────────────────────────────────────────────

  @override
  Future<String> uploadPhoto(Uint8List bytes, String fileName) async {
    final ref = _storage.ref('students/$fileName');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }
}
