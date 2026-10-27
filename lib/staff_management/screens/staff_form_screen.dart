import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/staff_model.dart';
import '../services/firebase_staff_service.dart';
import '../widgets/increments.dart';
import '../../access/session_service.dart';

/// Five-step staff registration form, ported from gd_college's Staff page:
/// personal info → address & contact → IDs → education & documents →
/// employment, salary increments and letters.
class StaffFormScreen extends StatefulWidget {
  final StaffModel? existing;

  const StaffFormScreen({super.key, this.existing});

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _service = FirebaseStaffService();
  final _sessionService = SessionService();
  final _pageController = PageController();
  final _picker = ImagePicker();

  bool get _isEdit => widget.existing != null;

  /// Whether the signed-in user may see/edit salary. Fail closed until the
  /// live session resolves.
  bool _canViewSalary = false;

  int _currentStep = 0;
  static const _totalSteps = 5;
  static const _stepTitles = [
    'Personal Info',
    'Address & Contact',
    'IDs & Certificates',
    'Education',
    'Employment & Fees',
  ];

  final List<GlobalKey<FormState>> _formKeys =
      List.generate(_totalSteps, (_) => GlobalKey<FormState>());

  // Step 1 controllers.
  final _nameCtrl = TextEditingController();
  final _fatherCtrl = TextEditingController();
  final _motherCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  DateTime? _dob;
  String _gender = '';
  String _caste = '';

  // Step 2 controllers.
  final _addressCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _mobile1Ctrl = TextEditingController();
  final _mobile2Ctrl = TextEditingController();

  // Step 3 controllers.
  final _aadharNoCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _familyIdCtrl = TextEditingController();

  // Step 5 controllers.
  final _salaryCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _joiningCtrl = TextEditingController();
  final _relievingCtrl = TextEditingController();
  final _staffIdCtrl = TextEditingController();
  DateTime? _joining;
  DateTime? _relieving;
  String _course = '';
  StaffGroup? _pickedGroup;
  List<StaffIncrement> _increments = [];

  // Photo + document state: stored URL wins unless a fresh pick replaces it.
  Uint8List? _photoBytes;
  String _photoUrl = '';
  final Map<String, Uint8List> _docBytes = {};
  final Map<String, String> _docUrls = {};
  final List<Uint8List> _expBytes = [];
  final List<String> _expNames = [];
  List<String> _expUrls = [];
  final List<Uint8List> _otherBytes = [];
  final List<String> _otherNames = [];
  List<String> _otherUrls = [];

  bool _saving = false;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    // Salary fields are hidden until the live session confirms access.
    _sessionService.watchSession().first.then((s) {
      if (mounted) {
        setState(() => _canViewSalary = s?.canViewStaffSalary ?? false);
      }
    });
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _fatherCtrl.text = e.fatherName;
      _motherCtrl.text = e.motherName;
      _dob = e.dob;
      _dobCtrl.text = _fmtDate(e.dob);
      _gender = e.gender;
      _caste = e.caste;
      _addressCtrl.text = e.address;
      _villageCtrl.text = e.village;
      _districtCtrl.text = e.district;
      _stateCtrl.text = e.state;
      _pinCtrl.text = e.pin;
      _mobile1Ctrl.text = e.mobileNo1;
      _mobile2Ctrl.text = e.mobileNo2;
      _aadharNoCtrl.text = e.aadharNumber;
      _panCtrl.text = e.panCard;
      _familyIdCtrl.text = e.familyId;
      _salaryCtrl.text = e.salary;
      _designationCtrl.text = e.designation;
      _joining = e.dateOfJoining;
      _joiningCtrl.text = _fmtDate(e.dateOfJoining);
      _relieving = e.dateOfRelieving;
      _relievingCtrl.text = _fmtDate(e.dateOfRelieving);
      _staffIdCtrl.text = e.staffId;
      _course = e.course;
      _pickedGroup =
          (e.group ?? '').isNotEmpty ? staffGroupOfStored(e.group) : null;
      _increments = List.of(e.increments);
      _photoUrl = e.photoUrl;
      _docUrls.addAll({
        'aadhar': e.aadharUrl,
        'pan': e.panUrl,
        'tenth': e.tenthUrl,
        'twelfth': e.twelfthUrl,
        'graduation': e.graduationUrl,
        'postGraduation': e.postGraduationUrl,
        'diploma': e.diplomaUrl,
        'net': e.netUrl,
        'phd': e.phdUrl,
        'sc': e.scCertificateUrl,
        'bc': e.bcCertificateUrl,
        'appointment': e.appointmentLetterUrl,
        'joiningLetter': e.joiningLetterUrl,
        'university': e.universityApprovalUrl,
        'resignation': e.resignationLetterUrl,
      });
      _expUrls = List.of(e.experienceCertificateUrls);
      _otherUrls = List.of(e.otherFileUrls);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _fatherCtrl.dispose();
    _motherCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _mobile1Ctrl.dispose();
    _mobile2Ctrl.dispose();
    _aadharNoCtrl.dispose();
    _panCtrl.dispose();
    _familyIdCtrl.dispose();
    _salaryCtrl.dispose();
    _designationCtrl.dispose();
    _joiningCtrl.dispose();
    _relievingCtrl.dispose();
    _staffIdCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<DateTime?> _pickDate(DateTime? initial, {bool pastOnly = true}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate:
          pastOnly ? now : now.add(const Duration(days: 365 * 10)),
    );
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  Future<void> _pickDoc(String key) async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _docBytes[key] = bytes);
  }

  void _clearDoc(String key) {
    setState(() {
      _docBytes.remove(key);
      _docUrls[key] = '';
    });
  }

  Future<void> _addMulti(List<Uint8List> list, List<String> names) async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      list.add(bytes);
      names.add(file.name);
    });
  }

  StaffGroup get _effectiveGroup =>
      _pickedGroup ??
      staffGroupOfCourse(_course);

  void _goNext() {
    if (!(_formKeys[_currentStep].currentState?.validate() ?? false)) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _goPrev() {
    if (_currentStep == 0) return;
    setState(() => _currentStep--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  String _docUrl(String key) => _docUrls[key] ?? '';

  Future<String> _uploadBytes(
      Uint8List bytes, String path, String label) async {
    setState(() => _uploadStatus = '$label…');
    return _service.uploadFile(bytes, path);
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _uploadStatus = 'Preparing upload…';
    });
    try {
      final staff = StaffModel(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        fatherName: _fatherCtrl.text.trim(),
        motherName: _motherCtrl.text.trim(),
        dob: _dob,
        gender: _gender,
        caste: _caste,
        address: _addressCtrl.text.trim(),
        village: _villageCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        pin: _pinCtrl.text.trim(),
        mobileNo1: _mobile1Ctrl.text.trim(),
        mobileNo2: _mobile2Ctrl.text.trim(),
        aadharNumber: _aadharNoCtrl.text.trim(),
        panCard: _panCtrl.text.trim(),
        familyId: _familyIdCtrl.text.trim(),
        photoUrl: _photoUrl,
        aadharUrl: _docUrl('aadhar'),
        panUrl: _docUrl('pan'),
        tenthUrl: _docUrl('tenth'),
        twelfthUrl: _docUrl('twelfth'),
        graduationUrl: _docUrl('graduation'),
        postGraduationUrl: _docUrl('postGraduation'),
        diplomaUrl: _docUrl('diploma'),
        netUrl: _docUrl('net'),
        phdUrl: _docUrl('phd'),
        scCertificateUrl: _docUrl('sc'),
        bcCertificateUrl: _docUrl('bc'),
        appointmentLetterUrl: _docUrl('appointment'),
        joiningLetterUrl: _docUrl('joiningLetter'),
        universityApprovalUrl: _docUrl('university'),
        resignationLetterUrl: _docUrl('resignation'),
        experienceCertificateUrls: List.of(_expUrls),
        otherFileUrls: List.of(_otherUrls),
        // Viewers without salary access keep the stored values untouched.
        salary: _canViewSalary
            ? _salaryCtrl.text.trim()
            : (widget.existing?.salary ?? ''),
        designation: _designationCtrl.text.trim(),
        course: _course,
        increments: _canViewSalary
            ? List.of(_increments)
            : List.of(widget.existing?.increments ?? []),
        dateOfJoining: _joining,
        dateOfRelieving: _relieving,
        staffId: _staffIdCtrl.text.trim(),
        group: _effectiveGroup.name,
        createdAt: widget.existing?.createdAt,
        createdBy: widget.existing?.createdBy,
      );

      final ts = DateTime.now().millisecondsSinceEpoch;
      String docId;
      if (_isEdit) {
        docId = widget.existing!.id!;
      } else {
        setState(() => _uploadStatus = 'Creating record…');
        docId = await _service.create(_blankForUpload(staff));
      }

      final base = 'staff/$docId';
      if (_photoBytes != null) {
        staff.photoUrl = await _uploadBytes(
            _photoBytes!, '$base/photo_$ts.jpg', 'Uploading photo');
      }
      Future<void> uploadDoc(String key, String name) async {
        final bytes = _docBytes[key];
        if (bytes == null) return;
        final url = await _uploadBytes(
            bytes, '$base/${key}_$ts.jpg', 'Uploading $name');
        switch (key) {
          case 'aadhar':
            staff.aadharUrl = url;
            break;
          case 'pan':
            staff.panUrl = url;
            break;
          case 'tenth':
            staff.tenthUrl = url;
            break;
          case 'twelfth':
            staff.twelfthUrl = url;
            break;
          case 'graduation':
            staff.graduationUrl = url;
            break;
          case 'postGraduation':
            staff.postGraduationUrl = url;
            break;
          case 'diploma':
            staff.diplomaUrl = url;
            break;
          case 'net':
            staff.netUrl = url;
            break;
          case 'phd':
            staff.phdUrl = url;
            break;
          case 'sc':
            staff.scCertificateUrl = url;
            break;
          case 'bc':
            staff.bcCertificateUrl = url;
            break;
          case 'appointment':
            staff.appointmentLetterUrl = url;
            break;
          case 'joiningLetter':
            staff.joiningLetterUrl = url;
            break;
          case 'university':
            staff.universityApprovalUrl = url;
            break;
          case 'resignation':
            staff.resignationLetterUrl = url;
            break;
        }
      }

      await uploadDoc('aadhar', 'Aadhar');
      await uploadDoc('pan', 'PAN');
      await uploadDoc('tenth', '10th certificate');
      await uploadDoc('twelfth', '12th certificate');
      await uploadDoc('graduation', 'Graduation');
      await uploadDoc('postGraduation', 'Post-graduation');
      await uploadDoc('diploma', 'Diploma');
      await uploadDoc('net', 'NET');
      await uploadDoc('phd', 'PhD');
      await uploadDoc('sc', 'SC certificate');
      await uploadDoc('bc', 'BC certificate');
      await uploadDoc('appointment', 'Appointment letter');
      await uploadDoc('joiningLetter', 'Joining letter');
      await uploadDoc('university', 'University approval');
      await uploadDoc('resignation', 'Resignation letter');

      for (var i = 0; i < _expBytes.length; i++) {
        final url = await _uploadBytes(
            _expBytes[i], '$base/exp_${ts}_$i.jpg',
            'Uploading experience ${i + 1}');
        staff.experienceCertificateUrls.add(url);
      }
      for (var i = 0; i < _otherBytes.length; i++) {
        final url = await _uploadBytes(_otherBytes[i],
            '$base/file_${ts}_$i.jpg', 'Uploading file ${i + 1}');
        staff.otherFileUrls.add(url);
      }

      setState(() => _uploadStatus = 'Saving…');
      if (_isEdit) {
        await _service.update(docId, staff);
      } else {
        // Fill the placeholder created above with the final data (photo +
        // document URLs) without writing a second audit entry.
        final snap = await _service.watchAll().first;
        final created =
            snap.where((s) => s.id == docId).firstOrNull ?? staff;
        created.photoUrl = staff.photoUrl;
        created.aadharUrl = staff.aadharUrl;
        created.panUrl = staff.panUrl;
        created.tenthUrl = staff.tenthUrl;
        created.twelfthUrl = staff.twelfthUrl;
        created.graduationUrl = staff.graduationUrl;
        created.postGraduationUrl = staff.postGraduationUrl;
        created.diplomaUrl = staff.diplomaUrl;
        created.netUrl = staff.netUrl;
        created.phdUrl = staff.phdUrl;
        created.scCertificateUrl = staff.scCertificateUrl;
        created.bcCertificateUrl = staff.bcCertificateUrl;
        created.appointmentLetterUrl = staff.appointmentLetterUrl;
        created.joiningLetterUrl = staff.joiningLetterUrl;
        created.universityApprovalUrl = staff.universityApprovalUrl;
        created.resignationLetterUrl = staff.resignationLetterUrl;
        created.experienceCertificateUrls =
            List.of(staff.experienceCertificateUrls);
        created.otherFileUrls = List.of(staff.otherFileUrls);
        await _service.update(docId, created);
      }

      if (!mounted) return;
      setState(() => _saving = false);
      _showSuccess();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  /// Placeholder record for the create-first upload flow (avoids a create
  /// audit entry with empty file URLs, matching gd_college's flow).
  StaffModel _blankForUpload(StaffModel staff) {
    final copy = staff.clone();
    copy.photoUrl = '';
    copy.aadharUrl = '';
    copy.panUrl = '';
    copy.tenthUrl = '';
    copy.twelfthUrl = '';
    copy.graduationUrl = '';
    copy.postGraduationUrl = '';
    copy.diplomaUrl = '';
    copy.netUrl = '';
    copy.phdUrl = '';
    copy.scCertificateUrl = '';
    copy.bcCertificateUrl = '';
    copy.appointmentLetterUrl = '';
    copy.joiningLetterUrl = '';
    copy.universityApprovalUrl = '';
    copy.resignationLetterUrl = '';
    copy.experienceCertificateUrls = [];
    copy.otherFileUrls = [];
    return copy;
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF1A3C6E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Staff Updated!' : 'Staff Registered!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3C6E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isEdit
                  ? 'Changes saved successfully.'
                  : 'New record created successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          if (!_isEdit)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => const StaffFormScreen()),
                );
              },
              child: const Text('Add Another'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Staff' : 'Staff Registration',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goPrev,
              )
            : null,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _StepHeader(
                  current: _currentStep,
                  total: _totalSteps,
                  titles: _stepTitles),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepPersonal(),
                    _stepAddress(),
                    _stepIds(),
                    _stepEducation(),
                    _stepEmployment(),
                  ],
                ),
              ),
              _bottomBar(),
            ],
          ),
          if (_saving) _uploadOverlay(),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _goPrev,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A3C6E),
                  side: const BorderSide(color: Color(0xFF1A3C6E)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _goNext,
              icon: Icon(
                _currentStep == _totalSteps - 1
                    ? (_isEdit ? Icons.save : Icons.cloud_upload)
                    : Icons.arrow_forward,
                size: 18,
              ),
              label: Text(
                _currentStep == _totalSteps - 1
                    ? (_isEdit ? 'Save Changes' : 'Submit')
                    : 'Next',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1A3C6E)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isEdit ? 'Saving Changes' : 'Registering Staff',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A3C6E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _uploadStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Steps ────────────────────────────────────────────────────────────────

  Widget _stepPersonal() {
    return Form(
      key: _formKeys[0],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionHeader(title: 'Basic Details', icon: Icons.person),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full Name *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _fatherCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: "Father's Name *"),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? "Father's name is required"
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _motherCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: "Mother's Name *"),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? "Mother's name is required"
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _dobCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Date of Birth *',
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            onTap: () async {
              final d = await _pickDate(_dob);
              if (d == null) return;
              setState(() {
                _dob = d;
                _dobCtrl.text = _fmtDate(d);
              });
            },
            validator: (v) => (v == null || v.isEmpty)
                ? 'Date of birth is required'
                : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _gender.isEmpty ? null : _gender,
            decoration: const InputDecoration(labelText: 'Gender *'),
            items: StaffModel.genders
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _gender = v ?? ''),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Gender is required' : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _caste.isEmpty ? null : _caste,
            decoration: const InputDecoration(labelText: 'Caste'),
            items: StaffModel.castes
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _caste = v ?? ''),
          ),
          const SizedBox(height: 10),
          const _SectionHeader(title: 'Photo', icon: Icons.photo_camera),
          _photoTile(),
        ],
      ),
    );
  }

  Widget _photoTile() {
    final hasNew = _photoBytes != null;
    final hasUrl = _photoUrl.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasNew
                ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                : hasUrl
                    ? Image.network(_photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person, size: 28))
                    : const Icon(Icons.person, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasNew
                      ? 'New photo selected'
                      : hasUrl
                          ? 'Photo uploaded'
                          : 'No photo yet',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  'JPG or PNG from gallery',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _pickPhoto,
            child: Text(hasNew || hasUrl ? 'Change' : 'Pick'),
          ),
        ],
      ),
    );
  }

  Widget _stepAddress() {
    return Form(
      key: _formKeys[1],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionHeader(
              title: 'Address & Contact', icon: Icons.location_on),
          TextFormField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _villageCtrl,
            decoration:
                const InputDecoration(labelText: 'Village / Town'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _districtCtrl,
            decoration: const InputDecoration(labelText: 'District'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _stateCtrl,
            decoration: const InputDecoration(labelText: 'State'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(labelText: 'PIN Code'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _mobile1Ctrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration:
                const InputDecoration(labelText: 'Mobile No. 1 *'),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Mobile number is required';
              if (t.length != 10) return 'Enter a 10-digit number';
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _mobile2Ctrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration:
                const InputDecoration(labelText: 'Mobile No. 2 (optional)'),
          ),
        ],
      ),
    );
  }

  Widget _stepIds() {
    return Form(
      key: _formKeys[2],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionHeader(
              title: 'IDs & Certificates', icon: Icons.badge),
          TextFormField(
            controller: _aadharNoCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            decoration:
                const InputDecoration(labelText: 'Aadhar Number'),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return null;
              return t.length == 12
                  ? null
                  : 'Aadhar number must be 12 digits';
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _panCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'PAN Card'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _familyIdCtrl,
            decoration: const InputDecoration(labelText: 'Family ID'),
          ),
          const SizedBox(height: 16),
          _docTile('aadhar', 'Aadhar Card Photo'),
          _docTile('pan', 'PAN Card Photo'),
          _docTile('sc', 'SC Certificate'),
          _docTile('bc', 'BC Certificate'),
        ],
      ),
    );
  }

  Widget _stepEducation() {
    return Form(
      key: _formKeys[3],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionHeader(
              title: 'Education Documents', icon: Icons.school),
          Text(
            'Pick each certificate photo from the gallery. Existing uploads are kept unless replaced.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          _docTile('tenth', '10th Certificate'),
          _docTile('twelfth', '12th Certificate'),
          _docTile('graduation', 'Graduation'),
          _docTile('postGraduation', 'Post-Graduation'),
          _docTile('diploma', 'Diploma'),
          _docTile('net', 'NET Certificate'),
          _docTile('phd', 'PhD Certificate'),
        ],
      ),
    );
  }

  Widget _stepEmployment() {
    return Form(
      key: _formKeys[4],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionHeader(
              title: 'Employment', icon: Icons.work),
          DropdownButtonFormField<String>(
            initialValue:
                _pickedGroup?.label,
            decoration: const InputDecoration(labelText: 'Category *'),
            items: StaffGroup.values
                .map((g) =>
                    DropdownMenuItem(value: g.label, child: Text(g.label)))
                .toList(),
            onChanged: (v) => setState(() {
              _pickedGroup = StaffGroup.values.firstWhere(
                (g) => g.label == v,
                orElse: () => StaffGroup.mahendargarh,
              );
            }),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Category is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _designationCtrl,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(labelText: 'Designation *'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Designation is required'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _staffIdCtrl,
            decoration:
                const InputDecoration(labelText: 'Staff ID (optional)'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _course.isEmpty ? null : _course,
            decoration:
                const InputDecoration(labelText: 'Name of Course *'),
            items: StaffModel.courses
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _course = v ?? ''),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Course is required' : null,
          ),
          const SizedBox(height: 10),
          if (_canViewSalary)
            TextFormField(
              controller: _salaryCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(labelText: 'Salary *'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Salary is required'
                  : null,
            ),
          if (_canViewSalary) const SizedBox(height: 10),
          TextFormField(
            controller: _joiningCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Date of Joining *',
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            onTap: () async {
              final d = await _pickDate(_joining);
              if (d == null) return;
              setState(() {
                _joining = d;
                _joiningCtrl.text = _fmtDate(d);
              });
            },
            validator: (v) => (v == null || v.isEmpty)
                ? 'Date of joining is required'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _relievingCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Date of Relieving (optional)',
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            onTap: () async {
              final d = await _pickDate(_relieving);
              if (d == null) return;
              setState(() {
                _relieving = d;
                _relievingCtrl.text = _fmtDate(d);
              });
            },
          ),
          const SizedBox(height: 16),
          if (_canViewSalary)
            IncrementsList(
              entries: _increments,
              onChanged: (updated) =>
                  setState(() => _increments = updated),
            ),
          const SizedBox(height: 8),
          const _SectionHeader(
              title: 'Letters', icon: Icons.mail_outline),
          _docTile('appointment', 'Appointment Letter'),
          _docTile('joiningLetter', 'Joining Letter'),
          _docTile('university', 'University Approval'),
          _docTile('resignation', 'Resignation Letter'),
          const SizedBox(height: 8),
          const _SectionHeader(
              title: 'Additional Files', icon: Icons.folder_open),
          _multiTile(
            title: 'Experience Certificates',
            count: _expBytes.length + _expUrls.length,
            onAdd: () => _addMulti(_expBytes, _expNames),
            onClearNew: () => setState(() {
              _expBytes.clear();
              _expNames.clear();
            }),
          ),
          _multiTile(
            title: 'Supporting Files',
            count: _otherBytes.length + _otherUrls.length,
            onAdd: () => _addMulti(_otherBytes, _otherNames),
            onClearNew: () => setState(() {
              _otherBytes.clear();
              _otherNames.clear();
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _docTile(String key, String label) {
    final hasNew = _docBytes[key] != null;
    final url = _docUrls[key] ?? '';
    final hasUrl = url.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasNew
                ? Image.memory(_docBytes[key]!, fit: BoxFit.cover)
                : hasUrl
                    ? Image.network(url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                            Icons.insert_drive_file_outlined,
                            size: 18))
                    : const Icon(Icons.insert_drive_file_outlined,
                        size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  hasNew
                      ? 'New photo selected'
                      : hasUrl
                          ? 'Uploaded — tap Change to replace'
                          : 'Optional — gallery photo',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (hasNew || hasUrl)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove',
              onPressed: () => _clearDoc(key),
            ),
          TextButton(
            onPressed: () => _pickDoc(key),
            child: Text(hasNew || hasUrl ? 'Change' : 'Pick'),
          ),
        ],
      ),
    );
  }

  Widget _multiTile({
    required String title,
    required int count,
    required VoidCallback onAdd,
    required VoidCallback onClearNew,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('$count file(s)',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (count > 0)
            TextButton(onPressed: onClearNew, child: const Text('Clear new')),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int current;
  final int total;
  final List<String> titles;

  const _StepHeader({
    required this.current,
    required this.total,
    required this.titles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${current + 1} of $total — ${titles[current]}',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF1A3C6E)),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (current + 1) / total,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(
                  Color(0xFF1A3C6E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF1A3C6E)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1A3C6E))),
      ]),
    );
  }
}
