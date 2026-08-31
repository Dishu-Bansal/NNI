import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../student_management/models/student_model.dart';
import '../../student_management/services/firebase_student_service.dart';
import '../services/firebase_fees_service.dart';

/// Records a fee receipt for a student. The student is picked through
/// College → Course → Admission year → Name/Roll No dropdowns.
class ReceiptFormScreen extends StatefulWidget {
  const ReceiptFormScreen({super.key});

  @override
  State<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends State<ReceiptFormScreen> {
  final _feesService = FirebaseFeesService();
  final _studentService = FirebaseStudentService();
  final _formKey = GlobalKey<FormState>();

  List<StudentModel> _students = [];
  bool _studentsLoaded = false;

  String _college = 'Bahadurgarh';
  String _course = 'GNM';
  late int _year;
  StudentModel? _selectedStudent;

  final _amountCtrl = TextEditingController();
  final _modeCtrl = TextEditingController(text: 'Cash');
  final _receiptNoCtrl = TextEditingController();

  Uint8List? _photoBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _studentService.watchAll().first.then((s) {
      if (mounted) {
        setState(() {
          _students = s;
          _studentsLoaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _modeCtrl.dispose();
    _receiptNoCtrl.dispose();
    super.dispose();
  }

  List<StudentModel> get _filteredStudents => _students
      .where((s) =>
          s.college == _college &&
          s.course == _course &&
          s.admissionYear == _year)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void _selectStudent(StudentModel? s) {
    setState(() => _selectedStudent = s);
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
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a student')),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the fees received')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String photoUrl = '';
      if (_photoBytes != null) {
        photoUrl = await _feesService.uploadReceiptPhoto(
          _photoBytes!,
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }
      await _feesService.createReceipt(
        studentId: _selectedStudent!.id!,
        amount: amount,
        mode: _modeCtrl.text.trim(),
        receiptNumber: _receiptNoCtrl.text.trim(),
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text('Receipt saved — ₹${amount.toStringAsFixed(0)} for '
              '${_selectedStudent!.name}')));
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
    final filtered = _filteredStudents;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Add Receipt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // College / Course
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _college,
                    decoration: const InputDecoration(
                      labelText: 'College',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: StudentModel.colleges
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _college = v;
                          _selectedStudent = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _course,
                    decoration: const InputDecoration(
                      labelText: 'Course',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    items: StudentModel.courses
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _course = v;
                          _selectedStudent = null;
                        });
                      }
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Admission year
              DropdownButtonFormField<int>(
                initialValue: _year,
                decoration: const InputDecoration(
                  labelText: 'Admission Year',
                  prefixIcon: Icon(Icons.event),
                ),
                items: [
                  for (var y = 2026; y >= 2010; y--)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _year = v;
                      _selectedStudent = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              // Student name
              DropdownButtonFormField<StudentModel>(
                key: ValueKey('name-$_college-$_course-$_year'),
                initialValue: _selectedStudent,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: filtered
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: _selectStudent,
              ),
              const SizedBox(height: 12),
              // Roll no — shares the same selection as the name dropdown.
              DropdownButtonFormField<String>(
                key: ValueKey('roll-$_college-$_course-$_year'),
                initialValue: _selectedStudent?.id,
                decoration: const InputDecoration(
                  labelText: 'Roll No.',
                  prefixIcon: Icon(Icons.numbers),
                ),
                items: [
                  for (final s in filtered)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(s.rollNo.isEmpty ? '—' : s.rollNo),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) {
                    setState(() => _selectedStudent = null);
                    return;
                  }
                  final match =
                      filtered.where((s) => s.id == id).firstOrNull;
                  setState(() => _selectedStudent = match);
                },
              ),
              if (!_studentsLoaded)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Loading students…',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No students match College/Course/Year. Create the student first.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              const SizedBox(height: 16),

              // Fees received + mode
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,8}(\.\d{0,2})?')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Fees Received (₹) *',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownMenu<String>(
                    controller: _modeCtrl,
                    initialSelection: 'Cash',
                    label: const Text('Mode of Payment'),
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: 'Cash', label: 'Cash'),
                      DropdownMenuEntry(
                          value: 'Account-XXXX', label: 'Account-XXXX'),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Receipt number
              TextFormField(
                controller: _receiptNoCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Receipt Number (optional)',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Receipt photo
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_photoBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(_photoBytes!,
                              width: 48, height: 48, fit: BoxFit.cover),
                        )
                      else
                        Icon(Icons.receipt_long_outlined,
                            color: Colors.grey.shade600, size: 32),
                      const SizedBox(width: 10),
                      Text(
                        _photoBytes != null
                            ? 'Receipt photo attached'
                            : 'Add receipt photo (optional)',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ]),
                  ),
                ),
              ),

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
                      : const Text('Save Receipt',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
