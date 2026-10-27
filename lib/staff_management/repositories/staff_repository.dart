import 'dart:typed_data';

import '../models/staff_model.dart';

abstract class StaffRepository {
  Stream<List<StaffModel>> watchAll();

  Future<String> create(StaffModel staff);

  Future<void> update(String id, StaffModel staff);

  Future<void> delete(String id);

  /// Global log of every create / update / delete, newest first.
  Stream<List<StaffLog>> watchAllLogs();

  /// Log entries for one staff member, newest first.
  Stream<List<StaffLog>> watchLogsFor(String staffId);

  /// Uploads a photo and returns its download URL.
  Future<String> uploadPhoto(Uint8List bytes, String fileName);

  /// Uploads a generic file and returns its download URL.
  Future<String> uploadFile(Uint8List bytes, String storagePath);
}
