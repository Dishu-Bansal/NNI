/// One salary increment entry on a staff record.
class StaffIncrement {
  DateTime? date;
  String amount;

  StaffIncrement({this.date, this.amount = ''});

  factory StaffIncrement.fromMap(Map<String, dynamic> m) => StaffIncrement(
        date: m['date'] != null
            ? DateTime.tryParse(m['date'].toString())
            : null,
        amount: (m['amount'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {
        'date': date?.toIso8601String(),
        'amount': amount,
      };
}

/// Staff work-location categories: Mahendargarh / Hisar / Helper.
/// (Spelling matches [StudentModel.colleges] in this app.)
enum StaffGroup { mahendargarh, hisar, helper }

extension StaffGroupLabel on StaffGroup {
  String get label {
    switch (this) {
      case StaffGroup.mahendargarh:
        return 'Mahendargarh';
      case StaffGroup.hisar:
        return 'Hisar';
      case StaffGroup.helper:
        return 'Helper';
    }
  }
}

StaffGroup staffGroupOfStored(String? stored, {String byCourse = ''}) {
  if (stored != null && stored.isNotEmpty) {
    for (final g in StaffGroup.values) {
      if (g.name == stored) return g;
    }
  }
  return staffGroupOfCourse(byCourse);
}

StaffGroup staffGroupOfCourse(String course) {
  // Location cannot be derived from the course; Mahendargarh is the default
  // for legacy documents that predate the location categories.
  return StaffGroup.mahendargarh;
}

class StaffModel {
  String? id;

  // Step 1: Personal info.
  String name;
  String fatherName;
  String motherName;
  DateTime? dob;
  String gender;
  String caste;

  // Step 2: Address & contact.
  String address;
  String village;
  String district;
  String state;
  String pin;
  String mobileNo1;
  String mobileNo2;

  // Step 3: IDs.
  String aadharNumber;
  String panCard;
  String familyId;

  // Step 4: Education / employment documents (download URLs).
  String tenthUrl;
  String twelfthUrl;
  String graduationUrl;
  String postGraduationUrl;
  String diplomaUrl;
  String netUrl;
  String phdUrl;

  // Step 5: Employment.
  String salary;
  String designation;
  String course;
  List<StaffIncrement> increments;
  DateTime? dateOfJoining;
  DateTime? dateOfRelieving;
  String staffId;

  /// Explicit work-location category (mahendargarh/hisar/helper). Null on
  /// legacy documents — [resolvedGroup] then falls back to the default.
  String? group;

  // Files (download URLs).
  String photoUrl;
  String aadharUrl;
  String panUrl;
  String scCertificateUrl;
  String bcCertificateUrl;
  String appointmentLetterUrl;
  String joiningLetterUrl;
  String universityApprovalUrl;
  String resignationLetterUrl;
  List<String> experienceCertificateUrls;
  List<String> otherFileUrls;

  DateTime? createdAt;
  DateTime? updatedAt;
  String? createdBy;
  String? lastUpdatedBy;

  static const List<String> courses = [
    'ANM',
    'GNM',
    'Other',
  ];

  static const List<String> genders = ['Male', 'Female', 'Other'];
  static const List<String> castes = [
    'General',
    'OBC',
    'SC',
    'ST',
    'EWS',
    'Other'
  ];

  StaffModel({
    this.id,
    this.name = '',
    this.fatherName = '',
    this.motherName = '',
    this.dob,
    this.gender = '',
    this.caste = '',
    this.address = '',
    this.village = '',
    this.district = '',
    this.state = '',
    this.pin = '',
    this.mobileNo1 = '',
    this.mobileNo2 = '',
    this.aadharNumber = '',
    this.panCard = '',
    this.familyId = '',
    this.tenthUrl = '',
    this.twelfthUrl = '',
    this.graduationUrl = '',
    this.postGraduationUrl = '',
    this.diplomaUrl = '',
    this.netUrl = '',
    this.phdUrl = '',
    this.salary = '',
    this.designation = '',
    this.course = '',
    this.increments = const [],
    this.dateOfJoining,
    this.dateOfRelieving,
    this.staffId = '',
    this.group,
    this.photoUrl = '',
    this.aadharUrl = '',
    this.panUrl = '',
    this.scCertificateUrl = '',
    this.bcCertificateUrl = '',
    this.appointmentLetterUrl = '',
    this.joiningLetterUrl = '',
    this.universityApprovalUrl = '',
    this.resignationLetterUrl = '',
    this.experienceCertificateUrls = const [],
    this.otherFileUrls = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.lastUpdatedBy,
  });

  StaffGroup get resolvedGroup =>
      staffGroupOfStored(group, byCourse: course);

  StaffModel clone() => StaffModel(
        id: id,
        name: name,
        fatherName: fatherName,
        motherName: motherName,
        dob: dob,
        gender: gender,
        caste: caste,
        address: address,
        village: village,
        district: district,
        state: state,
        pin: pin,
        mobileNo1: mobileNo1,
        mobileNo2: mobileNo2,
        aadharNumber: aadharNumber,
        panCard: panCard,
        familyId: familyId,
        tenthUrl: tenthUrl,
        twelfthUrl: twelfthUrl,
        graduationUrl: graduationUrl,
        postGraduationUrl: postGraduationUrl,
        diplomaUrl: diplomaUrl,
        netUrl: netUrl,
        phdUrl: phdUrl,
        salary: salary,
        designation: designation,
        course: course,
        increments: List.of(increments),
        dateOfJoining: dateOfJoining,
        dateOfRelieving: dateOfRelieving,
        staffId: staffId,
        group: group,
        photoUrl: photoUrl,
        aadharUrl: aadharUrl,
        panUrl: panUrl,
        scCertificateUrl: scCertificateUrl,
        bcCertificateUrl: bcCertificateUrl,
        appointmentLetterUrl: appointmentLetterUrl,
        joiningLetterUrl: joiningLetterUrl,
        universityApprovalUrl: universityApprovalUrl,
        resignationLetterUrl: resignationLetterUrl,
        experienceCertificateUrls: List.of(experienceCertificateUrls),
        otherFileUrls: List.of(otherFileUrls),
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy,
        lastUpdatedBy: lastUpdatedBy,
      );

  factory StaffModel.fromFirestore(String id, Map<String, dynamic> d) =>
      StaffModel(
        id: id,
        name: d['name'] ?? '',
        fatherName: d['fatherName'] ?? '',
        motherName: d['motherName'] ?? '',
        dob: d['dob'] != null ? DateTime.tryParse(d['dob'].toString()) : null,
        gender: d['gender'] ?? '',
        caste: d['caste'] ?? '',
        address: d['address'] ?? '',
        village: d['village'] ?? '',
        district: d['district'] ?? '',
        state: d['state'] ?? '',
        pin: d['pin'] ?? '',
        mobileNo1: d['mobileNo1'] ?? '',
        mobileNo2: d['mobileNo2'] ?? '',
        aadharNumber: d['aadharNumber'] ?? '',
        panCard: d['panCard'] ?? '',
        familyId: d['familyId'] ?? '',
        tenthUrl: d['tenthUrl'] ?? d['tenth'] ?? '',
        twelfthUrl: d['twelfthUrl'] ?? d['twelfth'] ?? '',
        graduationUrl: d['graduationUrl'] ?? d['graduation'] ?? '',
        postGraduationUrl:
            d['postGraduationUrl'] ?? d['postGraduation'] ?? '',
        diplomaUrl: d['diplomaUrl'] ?? d['diploma'] ?? '',
        netUrl: d['netUrl'] ?? d['net'] ?? '',
        phdUrl: d['phdUrl'] ?? d['phd'] ?? '',
        salary: (d['salary'] ?? '').toString(),
        designation: (d['designation'] ?? '').toString(),
        course: (d['course'] ?? '').toString(),
        increments: (d['increments'] as List<dynamic>? ?? [])
            .map((e) => StaffIncrement.fromMap(
                (e as Map).cast<String, dynamic>()))
            .toList(),
        dateOfJoining: d['dateOfJoining'] != null
            ? DateTime.tryParse(d['dateOfJoining'].toString())
            : null,
        dateOfRelieving: d['dateOfRelieving'] != null
            ? DateTime.tryParse(d['dateOfRelieving'].toString())
            : null,
        staffId: (d['staffId'] ?? '').toString(),
        group: d['group'] as String?,
        photoUrl: d['photoUrl'] ?? '',
        aadharUrl: d['aadharUrl'] ?? d['aadharurl'] ?? '',
        panUrl: d['panUrl'] ?? d['panurl'] ?? '',
        scCertificateUrl: d['scCertificateUrl'] ?? '',
        bcCertificateUrl: d['bcCertificateUrl'] ?? '',
        appointmentLetterUrl: d['appointmentLetterUrl'] ?? '',
        joiningLetterUrl: d['joiningLetterUrl'] ?? '',
        universityApprovalUrl: d['universityApprovalUrl'] ?? '',
        resignationLetterUrl: d['resignationLetterUrl'] ?? '',
        experienceCertificateUrls:
            List<String>.from(d['experienceCertificateUrls'] ?? const []),
        otherFileUrls: List<String>.from(d['otherFileUrls'] ?? const []),
        createdAt: d['createdAt'] != null
            ? DateTime.tryParse(d['createdAt'].toString())
            : null,
        updatedAt: d['updatedAt'] != null
            ? DateTime.tryParse(d['updatedAt'].toString())
            : null,
        createdBy: d['createdBy'] ?? '',
        lastUpdatedBy: d['lastUpdatedBy'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'fatherName': fatherName,
        'motherName': motherName,
        'dob': dob?.toIso8601String(),
        'gender': gender,
        'caste': caste,
        'address': address,
        'village': village,
        'district': district,
        'state': state,
        'pin': pin,
        'mobileNo1': mobileNo1,
        'mobileNo2': mobileNo2,
        'aadharNumber': aadharNumber,
        'panCard': panCard,
        'familyId': familyId,
        'tenthUrl': tenthUrl,
        'twelfthUrl': twelfthUrl,
        'graduationUrl': graduationUrl,
        'postGraduationUrl': postGraduationUrl,
        'diplomaUrl': diplomaUrl,
        'netUrl': netUrl,
        'phdUrl': phdUrl,
        'salary': salary,
        'designation': designation,
        'course': course,
        'increments': increments.map((e) => e.toMap()).toList(),
        'dateOfJoining': dateOfJoining?.toIso8601String(),
        'dateOfRelieving': dateOfRelieving?.toIso8601String(),
        'staffId': staffId,
        'group': group ?? resolvedGroup.name,
        'photoUrl': photoUrl,
        'aadharUrl': aadharUrl,
        'panUrl': panUrl,
        'scCertificateUrl': scCertificateUrl,
        'bcCertificateUrl': bcCertificateUrl,
        'appointmentLetterUrl': appointmentLetterUrl,
        'joiningLetterUrl': joiningLetterUrl,
        'universityApprovalUrl': universityApprovalUrl,
        'resignationLetterUrl': resignationLetterUrl,
        'experienceCertificateUrls': experienceCertificateUrls,
        'otherFileUrls': otherFileUrls,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'createdBy': createdBy ?? '',
        'lastUpdatedBy': lastUpdatedBy ?? '',
      };
}

/// Audit record for create / update / delete actions on staff.
class StaffLog {
  String? id;
  String staffId;
  String staffName;
  String action; // 'create' | 'update' | 'delete'
  String changedBy;
  String detail;
  DateTime timestamp;

  StaffLog({
    this.id,
    this.staffId = '',
    this.staffName = '',
    this.action = 'update',
    this.changedBy = '',
    this.detail = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory StaffLog.fromFirestore(String id, Map<String, dynamic> d) =>
      StaffLog(
        id: id,
        staffId: d['staffId'] ?? '',
        staffName: d['staffName'] ?? '',
        action: d['action'] ?? 'update',
        changedBy: d['changedBy'] ?? '',
        detail: d['detail'] ?? '',
        timestamp: d['timestamp'] != null
            ? DateTime.tryParse(d['timestamp'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
        'staffId': staffId,
        'staffName': staffName,
        'action': action,
        'changedBy': changedBy,
        'detail': detail,
        'timestamp': timestamp.toIso8601String(),
      };
}
