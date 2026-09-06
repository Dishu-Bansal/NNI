import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/student_model.dart';
import '../services/firebase_student_service.dart';

/// One-page student form. GNM students get Year 1-3 fee rows, ANM students
/// Year 1-2, and both share an add-more misc fee type list.
class StudentFormScreen extends StatefulWidget {
  final StudentModel? existing;

  const StudentFormScreen({super.key, this.existing});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _FeeRow {
  final bool isYearFee;
  final TextEditingController typeCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController commentCtrl;

  _FeeRow({
    required this.isYearFee,
    required String type,
    String amount = '',
    String comment = '',
  })  : typeCtrl = TextEditingController(text: type),
        amountCtrl = TextEditingController(text: amount),
        commentCtrl = TextEditingController(text: comment);

  void dispose() {
    typeCtrl.dispose();
    amountCtrl.dispose();
    commentCtrl.dispose();
  }
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _service = FirebaseStudentService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _rollNoCtrl = TextEditingController();
  final _hnmcNoCtrl = TextEditingController();
  final _registrationNoCtrl = TextEditingController();
  final _mothersNameCtrl = TextEditingController();
  final _fathersNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _familyIdCtrl = TextEditingController();
  final _aadharNoCtrl = TextEditingController();
  final _bankAccountNoCtrl = TextEditingController();

  String _course = 'GNM';
  String _college = 'Mahendargarh';
  late int _admissionYear;
  DateTime? _dateOfBirth;

  // Photo state: a freshly picked image wins over the stored URL.
  Uint8List? _photoBytes;
  String _photoUrl = '';

  final List<_FeeRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _admissionYear = existing?.admissionYear ?? DateTime.now().year;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _rollNoCtrl.text = existing.rollNo;
      _course = existing.course;
      _college = existing.college;
      _photoUrl = existing.photoUrl;
      _hnmcNoCtrl.text = existing.hnmcNo;
      _registrationNoCtrl.text = existing.registrationNo;
      _mothersNameCtrl.text = existing.mothersName;
      _fathersNameCtrl.text = existing.fathersName;
      _addressCtrl.text = existing.address;
      _dateOfBirth = existing.dateOfBirth;
      _dobCtrl.text = _fmtDob(existing.dateOfBirth);
      _familyIdCtrl.text = existing.familyId;
      _aadharNoCtrl.text = existing.aadharNo;
      _bankAccountNoCtrl.text = existing.bankAccountNo;
      _initRowsFrom(existing);
    } else {
      _initDefaultRows();
    }
  }

  void _initRowsFrom(StudentModel existing) {
    final yearCount = StudentModel.yearFeeCount(existing.course);
    for (var i = 1; i <= yearCount; i++) {
      final type = 'Year $i Fee';
      final match =
          existing.fees.where((f) => f.type == type).firstOrNull;
      _rows.add(_FeeRow(
        isYearFee: true,
        type: type,
        amount: match != null ? _fmtAmount(match.amount) : '',
        comment: match?.comment ?? '',
      ));
    }
    for (final f in existing.fees) {
      if (!RegExp(r'^Year \d+ Fee$').hasMatch(f.type)) {
        _rows.add(_FeeRow(
          isYearFee: false,
          type: f.type,
          amount: _fmtAmount(f.amount),
          comment: f.comment,
        ));
      }
    }
  }

  void _initDefaultRows() {
    for (var i = 1; i <= StudentModel.yearFeeCount(_course); i++) {
      _rows.add(_FeeRow(isYearFee: true, type: 'Year $i Fee'));
    }
  }

  String _fmtAmount(double a) =>
      a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toString();

  /// Date of birth shown as dd/mm/yyyy (empty when unset).
  String _fmtDob(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ??
          DateTime(now.year - 18, now.month, now.day < 28 ? now.day : 28),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (picked == null) return;
    setState(() {
      _dateOfBirth = picked;
      _dobCtrl.text = _fmtDob(picked);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollNoCtrl.dispose();
    _hnmcNoCtrl.dispose();
    _registrationNoCtrl.dispose();
    _mothersNameCtrl.dispose();
    _fathersNameCtrl.dispose();
    _addressCtrl.dispose();
    _dobCtrl.dispose();
    _familyIdCtrl.dispose();
    _aadharNoCtrl.dispose();
    _bankAccountNoCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _setCourse(String course) {
    setState(() {
      _course = course;
      final yearRows = _rows.where((r) => r.isYearFee).toList();
      final target = StudentModel.yearFeeCount(course);
      while (yearRows.length < target) {
        final idx = yearRows.length + 1;
        final row = _FeeRow(isYearFee: true, type: 'Year $idx Fee');
        _rows.insert(yearRows.length, row);
        yearRows.add(row);
      }
      while (yearRows.length > target) {
        final row = yearRows.removeLast();
        _rows.removeAt(_rows.indexOf(row));
        row.dispose();
      }
    });
  }

  void _addMiscRow() {
    setState(() => _rows.add(_FeeRow(isYearFee: false, type: 'Misc')));
  }

  void _removeRow(int index) {
    final row = _rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _photoBytes = bytes);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fees = _rows
        .map((r) => FeeEntry(
              type: r.typeCtrl.text.trim().isEmpty
                  ? 'Misc'
                  : r.typeCtrl.text.trim(),
              amount: double.tryParse(r.amountCtrl.text.trim()) ?? 0,
              comment: r.commentCtrl.text.trim(),
            ))
        .toList();

    final student = StudentModel(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      rollNo: _rollNoCtrl.text.trim(),
      course: _course,
      college: _college,
      admissionYear: _admissionYear,
      photoUrl: _photoUrl,
      fees: fees,
      hnmcNo: _hnmcNoCtrl.text.trim(),
      registrationNo: _registrationNoCtrl.text.trim(),
      mothersName: _mothersNameCtrl.text.trim(),
      fathersName: _fathersNameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      dateOfBirth: _dateOfBirth,
      familyId: _familyIdCtrl.text.trim(),
      aadharNo: _aadharNoCtrl.text.trim(),
      bankAccountNo: _bankAccountNoCtrl.text.trim(),
    );

    setState(() => _saving = true);
    try {
      if (_photoBytes != null) {
        final url = await _service.uploadPhoto(
          _photoBytes!,
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        student.photoUrl = url;
      }
      if (widget.existing == null) {
        await _service.create(student);
      } else {
        await _service.update(widget.existing!.id!, student);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text(widget.existing == null
              ? '${student.name} added'
              : '${student.name} updated')));
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Student' : 'Edit Student'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _photoPicker()),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter the name' : null,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rollNoCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Roll No. (optional)',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 16),
              _profileTextField(
                controller: _hnmcNoCtrl,
                label: 'HNMC No.',
                icon: Icons.numbers,
              ),
              const SizedBox(height: 12),
              _profileTextField(
                controller: _registrationNoCtrl,
                label: 'Registration No.',
                icon: Icons.confirmation_number_outlined,
              ),
              const SizedBox(height: 12),
              _profileTextField(
                controller: _mothersNameCtrl,
                label: "Mother's Name",
                icon: Icons.female,
              ),
              const SizedBox(height: 12),
              _profileTextField(
                controller: _fathersNameCtrl,
                label: "Father's Name",
                icon: Icons.male,
              ),
              const SizedBox(height: 12),
              _profileTextField(
                controller: _addressCtrl,
                label: 'Address',
                icon: Icons.home_outlined,
                multiline: true,
              ),
              const SizedBox(height: 12),
              _dobField(),
              const SizedBox(height: 12),
              _profileTextField(
                controller: _familyIdCtrl,
                label: 'Family ID',
                icon: Icons.group_outlined,
              ),
              const SizedBox(height: 12),
              _profileTextField(
                controller: _aadharNoCtrl,
                label: 'Aadhar Card No.',
                icon: Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return t.length == 12
                      ? null
                      : 'Aadhar number must be 12 digits';
                },
              ),
              const SizedBox(height: 12),
              _profileTextField(
                controller: _bankAccountNoCtrl,
                label: 'Bank Account No.',
                icon: Icons.account_balance_outlined,
                keyboardType: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(18),
                ],
              ),
              const SizedBox(height: 16),
              // Course
              const Text('Course',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'GNM', label: Text('GNM')),
                  ButtonSegment(value: 'ANM', label: Text('ANM')),
                ],
                selected: {_course},
                onSelectionChanged: (s) => _setCourse(s.first),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _admissionYear,
                    decoration: const InputDecoration(
                      labelText: 'Admission Year',
                      prefixIcon: Icon(Icons.event),
                    ),
                    items: [
                      for (var y = 2026; y >= 2010; y--)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _admissionYear = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _college,
                    decoration: const InputDecoration(
                      labelText: 'College',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: StudentModel.colleges
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _college = v);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // Fees
              Row(children: [
                const Text('Fees',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addMiscRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Fee Type'),
                ),
              ]),
              for (var i = 0; i < _rows.length; i++) _feeCard(i, _rows[i]),
              if (_rows.isEmpty)
                Text('No fees added',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),

              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          widget.existing == null ? 'Add Student' : 'Save Changes',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Text input for one optional profile field.
  Widget _profileTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextCapitalization capitalization = TextCapitalization.words,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    bool multiline = false,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: capitalization,
      keyboardType: keyboardType ??
          (multiline ? TextInputType.multiline : TextInputType.text),
      textInputAction:
          multiline ? TextInputAction.newline : TextInputAction.next,
      maxLines: multiline ? 3 : 1,
      inputFormatters: formatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: multiline,
      ),
    );
  }

  Widget _dobField() {
    return TextFormField(
      controller: _dobCtrl,
      readOnly: true,
      onTap: _pickDob,
      decoration: const InputDecoration(
        labelText: 'Date of Birth',
        hintText: 'dd/mm/yyyy',
        prefixIcon: Icon(Icons.cake_outlined),
        suffixIcon: Icon(Icons.calendar_today, size: 18),
      ),
    );
  }

  Widget _photoPicker() {
    final Widget content;
    if (_photoBytes != null) {
      content = ClipOval(
        child: Image.memory(_photoBytes!, width: 110, height: 110,
            fit: BoxFit.cover),
      );
    } else if (_photoUrl.isNotEmpty) {
      content = ClipOval(
        child: Image.network(_photoUrl, width: 110, height: 110,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _photoPlaceholder()),
      );
    } else {
      content = _photoPlaceholder();
    }
    return InkWell(
      onTap: _pickPhoto,
      customBorder: const CircleBorder(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt,
                  size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 56, color: Colors.grey.shade500),
    );
  }

  Widget _feeCard(int index, _FeeRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: row.isYearFee
                  ? Text(
                      row.typeCtrl.text,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    )
                  : TextField(
                      controller: row.typeCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Fee Type',
                        isDense: true,
                      ),
                    ),
            ),
            if (!row.isYearFee)
              IconButton(
                onPressed: () => _removeRow(index),
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 20),
                tooltip: 'Remove',
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: row.amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,8}(\.\d{0,2})?')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  isDense: true,
                  prefixText: '₹ ',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                controller: row.commentCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  isDense: true,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
