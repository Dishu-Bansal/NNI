import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../student_management/models/student_model.dart';
import '../../student_management/services/firebase_student_service.dart';
import '../services/firebase_fees_service.dart';

/// Records a fee receipt for a student. The student is picked through
/// College → Course → Admission year → a searchable student list.
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

  String _college = 'Mahendargarh';
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

  Future<void> _openStudentPicker() async {
    final students = _filteredStudents;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No students match College/Course/Year.')));
      return;
    }
    final picked = await showModalBottomSheet<StudentModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _StudentPickerSheet(students: students),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedStudent = picked);
    }
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
              // Student — opens a searchable picker of the students matching
              // the college/course/year chosen above.
              InkWell(
                onTap: _saving ? null : _openStudentPicker,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Student *',
                    prefixIcon: Icon(Icons.person_search_outlined),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  isEmpty: _selectedStudent == null,
                  child: _selectedStudent == null
                      ? Text(
                          'Search by name, father, roll no. or HNMC',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        )
                      : Text(
                          _selectedStudent!.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              if (_selectedStudent != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _StudentSummary(student: _selectedStudent!),
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

// ── Searchable student picker (bottom sheet) ────────────────────────────────

/// Bottom-sheet list of candidate students with a search box on top.
/// Entries show the student's name, father's name and roll no. + HNMC no.
class _StudentPickerSheet extends StatefulWidget {
  final List<StudentModel> students;

  const _StudentPickerSheet({required this.students});

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<StudentModel> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.students;
    return widget.students
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.fathersName.toLowerCase().contains(q) ||
            s.rollNo.toLowerCase().contains(q) ||
            s.hnmcNo.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(children: [
            const Text('Select Student',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search by name, father, roll no. or HNMC',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text('No students match your search.',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey.shade100),
                  itemBuilder: (_, i) => _StudentPickerTile(
                    student: results[i],
                    onTap: () => Navigator.pop(context, results[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _StudentPickerTile extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;

  const _StudentPickerTile({required this.student, required this.onTap});

  String get _initial {
    final n = student.name.trim();
    return n.isEmpty ? '?' : n.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ids = <String>[
      if (student.rollNo.isNotEmpty) 'Roll: ${student.rollNo}',
      if (student.hnmcNo.isNotEmpty) 'HNMC: ${student.hnmcNo}',
    ].join('  •  ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1A3C6E).withValues(alpha: 0.12),
            child: Text(_initial,
                style: const TextStyle(
                    color: Color(0xFF1A3C6E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (student.fathersName.isNotEmpty)
                  Text('Father: ${student.fathersName}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700)),
                if (ids.isNotEmpty)
                  Text(ids,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

/// Small confirmation card under the student field showing the picked
/// student's father's name and roll no. + HNMC no. (when present).
class _StudentSummary extends StatelessWidget {
  final StudentModel student;

  const _StudentSummary({required this.student});

  @override
  Widget build(BuildContext context) {
    final hasFather = student.fathersName.isNotEmpty;
    final ids = <String>[
      if (student.rollNo.isNotEmpty) 'Roll: ${student.rollNo}',
      if (student.hnmcNo.isNotEmpty) 'HNMC: ${student.hnmcNo}',
    ];
    if (!hasFather && ids.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3C6E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasFather)
            Text('Father: ${student.fathersName}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
          if (ids.isNotEmpty)
            Text(ids.join('  •  '),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
