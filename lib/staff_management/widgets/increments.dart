import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/staff_model.dart';

/// Salary-increment editor used on the staff form (ported from gd_college).
class IncrementsList extends StatefulWidget {
  final List<StaffIncrement> entries;
  final void Function(List<StaffIncrement> updated) onChanged;

  const IncrementsList({
    super.key,
    required this.entries,
    required this.onChanged,
  });

  @override
  State<IncrementsList> createState() => _IncrementsListState();
}

class _IncrementsListState extends State<IncrementsList> {
  final List<TextEditingController> _amountControllers = [];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant IncrementsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    while (_amountControllers.length < widget.entries.length) {
      final idx = _amountControllers.length;
      _amountControllers.add(
        TextEditingController(text: widget.entries[idx].amount),
      );
    }
    while (_amountControllers.length > widget.entries.length) {
      _amountControllers.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final c in _amountControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    final updated = [...widget.entries, StaffIncrement()];
    _amountControllers.add(TextEditingController());
    widget.onChanged(updated);
  }

  void _removeEntry(int index) {
    final updated = [...widget.entries]..removeAt(index);
    _amountControllers.removeAt(index).dispose();
    widget.onChanged(updated);
  }

  Future<void> _pickDate(int index) async {
    final current = widget.entries[index].date;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    final updated = [...widget.entries];
    updated[index] = StaffIncrement(
      date: picked,
      amount: _amountControllers[index].text,
    );
    widget.onChanged(updated);
    setState(() {});
  }

  String _fmtDate(DateTime? d) => d == null
      ? 'Select date'
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Salary Increments',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            TextButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        if (widget.entries.isEmpty)
          Text(
            'No increments yet. Tap Add when the salary is revised.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        for (var i = 0; i < widget.entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () => _pickDate(i),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date',
                        prefixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _fmtDate(widget.entries[i].date),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountControllers[i],
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.currency_rupee, size: 18),
                    ),
                    onChanged: (v) {
                      final updated = [...widget.entries];
                      updated[i] =
                          StaffIncrement(date: updated[i].date, amount: v);
                      widget.onChanged(updated);
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _removeEntry(i)),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
      ],
    );
  }
}
