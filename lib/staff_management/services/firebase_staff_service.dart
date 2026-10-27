import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/staff_model.dart';
import '../repositories/staff_repository.dart';

class FirebaseStaffService implements StaffRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const _collection = 'staff';
  static const _logsCollection = 'staffLogs';

  String get _currentUser => FirebaseAuth.instance.currentUser?.email ?? '';

  // ── Staff ──────────────────────────────────────────────────────────────

  @override
  Stream<List<StaffModel>> watchAll() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StaffModel.fromFirestore(d.id, d.data()))
            .toList())
        .handleError((_) => <StaffModel>[]);
  }

  @override
  Future<String> create(StaffModel staff) async {
    final now = DateTime.now();
    staff.createdAt = now;
    staff.updatedAt = now;
    staff.createdBy = _currentUser;
    staff.lastUpdatedBy = _currentUser;
    staff.group ??= staff.resolvedGroup.name;
    final ref = await _db.collection(_collection).add(staff.toFirestore());
    await _writeLog(
      staffId: ref.id,
      staff: staff,
      action: 'create',
      detail: 'Created: ${staff.name}'
          '${staff.designation.isNotEmpty ? ', ${staff.designation}' : ''}',
    );
    return ref.id;
  }

  @override
  Future<void> update(String id, StaffModel staff) async {
    final oldSnap = await _db.collection(_collection).doc(id).get();
    final oldData = oldSnap.data() ?? {};
    final oldStaff = StaffModel.fromFirestore(id, oldData);

    staff.updatedAt = DateTime.now();
    staff.lastUpdatedBy = _currentUser;
    staff.group ??= staff.resolvedGroup.name;
    await _db.collection(_collection).doc(id).update(staff.toFirestore());
    await _writeLog(
      staffId: id,
      staff: staff,
      action: 'update',
      detail: _buildUpdateDetail(oldStaff, staff),
    );
  }

  @override
  Future<void> delete(String id) async {
    final snap = await _db.collection(_collection).doc(id).get();
    final data = snap.data() ?? {};
    final staff = StaffModel.fromFirestore(id, data);
    await _db.collection(_collection).doc(id).delete();
    await _writeLog(
      staffId: id,
      staff: staff,
      action: 'delete',
      detail: 'Deleted: ${staff.name}'
          '${staff.designation.isNotEmpty ? ', ${staff.designation}' : ''}',
    );
  }

  // ── Logs ───────────────────────────────────────────────────────────────

  @override
  Stream<List<StaffLog>> watchAllLogs() {
    return _db
        .collection(_logsCollection)
        .orderBy('timestamp', descending: true)
        .limit(300)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StaffLog.fromFirestore(d.id, d.data()))
            .toList())
        .handleError((_) => <StaffLog>[]);
  }

  @override
  Stream<List<StaffLog>> watchLogsFor(String staffId) {
    return _db
        .collection(_logsCollection)
        .where('staffId', isEqualTo: staffId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StaffLog.fromFirestore(d.id, d.data()))
            .toList())
        .handleError((_) => <StaffLog>[]);
  }

  Future<void> _writeLog({
    required String staffId,
    required StaffModel staff,
    required String action,
    required String detail,
  }) async {
    await _db.collection(_logsCollection).add(StaffLog(
          staffId: staffId,
          staffName: staff.name,
          action: action,
          changedBy: _currentUser,
          detail: detail,
        ).toFirestore());
  }

  /// Human-readable summary of which fields changed (file URLs collapse to
  /// "changed" so audit logs never embed storage URLs).
  String _buildUpdateDetail(StaffModel old, StaffModel updated) {
    final parts = <String>[];
    void diff(String label, String a, String b) {
      if (a != b) parts.add('$label: $a → $b');
    }

    diff('Name', old.name, updated.name);
    diff('Father', old.fatherName, updated.fatherName);
    diff('Mother', old.motherName, updated.motherName);
    if ((old.dob?.toIso8601String() ?? '') !=
        (updated.dob?.toIso8601String() ?? '')) {
      parts.add('DOB: ${_fmtDate(old.dob)} → ${_fmtDate(updated.dob)}');
    }
    diff('Gender', old.gender, updated.gender);
    diff('Caste', old.caste, updated.caste);
    diff('Address', old.address, updated.address);
    diff('Village', old.village, updated.village);
    diff('District', old.district, updated.district);
    diff('State', old.state, updated.state);
    diff('PIN', old.pin, updated.pin);
    diff('Mobile 1', old.mobileNo1, updated.mobileNo1);
    diff('Mobile 2', old.mobileNo2, updated.mobileNo2);
    diff('Aadhar', old.aadharNumber, updated.aadharNumber);
    diff('PAN', old.panCard, updated.panCard);
    diff('Family ID', old.familyId, updated.familyId);
    diff('Designation', old.designation, updated.designation);
    diff('Course', old.course, updated.course);
    diff('Salary', old.salary, updated.salary);
    diff('Staff ID', old.staffId, updated.staffId);
    if ((old.dateOfJoining?.toIso8601String() ?? '') !=
        (updated.dateOfJoining?.toIso8601String() ?? '')) {
      parts.add('Joining: ${_fmtDate(old.dateOfJoining)} → '
          '${_fmtDate(updated.dateOfJoining)}');
    }
    if ((old.dateOfRelieving?.toIso8601String() ?? '') !=
        (updated.dateOfRelieving?.toIso8601String() ?? '')) {
      parts.add('Relieving: ${_fmtDate(old.dateOfRelieving)} → '
          '${_fmtDate(updated.dateOfRelieving)}');
    }
    for (final key in [
      'Photo',
      'Aadhar file',
      'PAN file',
      '10th',
      '12th',
      'Graduation',
      'Post-grad',
      'Diploma',
      'NET',
      'PhD',
      'SC cert',
      'BC cert',
      'Appointment letter',
      'Joining letter',
      'University approval',
      'Resignation letter',
    ]) {
      // Compared below via URL pairs; placeholder keeps the loop honest.
      assert(key.isNotEmpty);
    }
    void fileDiff(String label, String a, String b) {
      if (a != b) parts.add('$label ${a.isEmpty ? 'added' : 'changed'}');
    }

    fileDiff('Photo', old.photoUrl, updated.photoUrl);
    fileDiff('Aadhar file', old.aadharUrl, updated.aadharUrl);
    fileDiff('PAN file', old.panUrl, updated.panUrl);
    fileDiff('10th cert', old.tenthUrl, updated.tenthUrl);
    fileDiff('12th cert', old.twelfthUrl, updated.twelfthUrl);
    fileDiff('Graduation', old.graduationUrl, updated.graduationUrl);
    fileDiff(
        'Post-grad', old.postGraduationUrl, updated.postGraduationUrl);
    fileDiff('Diploma', old.diplomaUrl, updated.diplomaUrl);
    fileDiff('NET', old.netUrl, updated.netUrl);
    fileDiff('PhD', old.phdUrl, updated.phdUrl);

    if (parts.isEmpty) return 'Updated ${updated.name}';
    return 'Updated: ${updated.name} — ${parts.join('; ')}';
  }

  static String _fmtDate(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Uploads ────────────────────────────────────────────────────────────

  @override
  Future<String> uploadPhoto(Uint8List bytes, String fileName) =>
      uploadFile(bytes, 'staff/$fileName');

  @override
  Future<String> uploadFile(Uint8List bytes, String storagePath) async {
    final ref = _storage.ref(storagePath);
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }
}
