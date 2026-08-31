/// One fee line on a student's record: a year fee (e.g. "Year 1 Fee") or a
/// misc fee type (e.g. "Misc - Uniform").
class FeeEntry {
  String type;
  double amount;
  String comment;

  FeeEntry({
    this.type = '',
    this.amount = 0,
    this.comment = '',
  });

  factory FeeEntry.fromMap(Map<String, dynamic> m) => FeeEntry(
    type: m['type'] ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    comment: m['comment'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'type': type,
    'amount': amount,
    'comment': comment,
  };
}

class StudentModel {
  String? id;
  String name;
  String course; // 'GNM' | 'ANM'
  String college; // 'Bahadurgarh' | 'Hisar'
  int admissionYear;
  String photoUrl;
  List<FeeEntry> fees;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? createdBy;
  String? lastUpdatedBy;

  static const List<String> courses = ['GNM', 'ANM'];
  static const List<String> colleges = ['Bahadurgarh', 'Hisar'];

  /// Year-fee count per course: GNM covers Years 1-3, ANM Years 1-2.
  static int yearFeeCount(String course) => course == 'GNM' ? 3 : 2;

  StudentModel({
    this.id,
    this.name = '',
    this.course = 'GNM',
    this.college = 'Bahadurgarh',
    this.admissionYear = 0,
    this.photoUrl = '',
    this.fees = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.lastUpdatedBy,
  });

  double get totalFees =>
      fees.fold(0, (sum, f) => sum + f.amount);

  factory StudentModel.fromFirestore(
      String id, Map<String, dynamic> d) =>
      StudentModel(
        id: id,
        name: d['name'] ?? '',
        course: d['course'] ?? 'GNM',
        college: d['college'] ?? '',
        admissionYear: (d['admissionYear'] as num?)?.toInt() ??
            DateTime.now().year,
        photoUrl: d['photoUrl'] ?? '',
        fees: (d['fees'] as List<dynamic>? ?? [])
            .map((e) => FeeEntry.fromMap(
                (e as Map).cast<String, dynamic>()))
            .toList(),
        createdAt: d['createdAt'] != null
            ? DateTime.tryParse(d['createdAt'])
            : null,
        updatedAt: d['updatedAt'] != null
            ? DateTime.tryParse(d['updatedAt'])
            : null,
        createdBy: d['createdBy'] ?? '',
        lastUpdatedBy: d['lastUpdatedBy'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'course': course,
    'college': college,
    'admissionYear': admissionYear,
    'photoUrl': photoUrl,
    'fees': fees.map((f) => f.toMap()).toList(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'createdBy': createdBy ?? '',
    'lastUpdatedBy': lastUpdatedBy ?? '',
  };
}

/// Audit record for create / update / delete actions on students.
class StudentLog {
  String? id;
  String studentId;
  String studentName;
  String action; // 'create' | 'update' | 'delete'
  String changedBy;
  String detail;
  DateTime timestamp;

  StudentLog({
    this.id,
    this.studentId = '',
    this.studentName = '',
    this.action = 'update',
    this.changedBy = '',
    this.detail = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory StudentLog.fromFirestore(
      String id, Map<String, dynamic> d) =>
      StudentLog(
        id: id,
        studentId: d['studentId'] ?? '',
        studentName: d['studentName'] ?? '',
        action: d['action'] ?? 'update',
        changedBy: d['changedBy'] ?? '',
        detail: d['detail'] ?? '',
        timestamp: d['timestamp'] != null
            ? DateTime.tryParse(d['timestamp']) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'studentName': studentName,
    'action': action,
    'changedBy': changedBy,
    'detail': detail,
    'timestamp': timestamp.toIso8601String(),
  };
}
