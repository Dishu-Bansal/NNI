import 'dart:typed_data';

import '../models/student_model.dart';

abstract class StudentRepository {
  Stream<List<StudentModel>> watchAll();

  Future<String> create(StudentModel student);

  Future<void> update(String id, StudentModel student);

  Future<void> delete(String id);

  /// Global log of every create / update / delete, newest first.
  Stream<List<StudentLog>> watchAllLogs();

  /// Uploads a photo and returns its download URL.
  Future<String> uploadPhoto(Uint8List bytes, String fileName);
}
