import 'package:flutter/material.dart';

import '../model/routine.dart';

/// What the editor returned. A null result from [showCellEditor] means cancelled.
class CellEdit {
  final ClassCell? cell;

  const CellEdit(this.cell);
}

Future<CellEdit?> showCellEditor(
  BuildContext context, {
  ClassCell? initial,
  required Map<String, String> teachers,
}) =>
    showDialog<CellEdit>(
      context: context,
      builder: (_) => _CellEditor(initial: initial, teachers: teachers),
    );

class _CellEditor extends StatefulWidget {
  final ClassCell? initial;
  final Map<String, String> teachers;

  const _CellEditor({required this.initial, required this.teachers});

  @override
  State<_CellEditor> createState() => _CellEditorState();
}

class _CellEditorState extends State<_CellEditor> {
  late final _course = TextEditingController(text: widget.initial?.course);
  late final _room = TextEditingController(text: widget.initial?.room);
  late TextEditingController _teacher;
  late bool _tough = widget.initial?.tough ?? false;
  bool _showErrors = false;

  @override
  void dispose() {
    _course.dispose();
    _room.dispose();
    super.dispose();
  }

  void _save() {
    if (_course.text.trim().isEmpty || _room.text.trim().isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.of(context).pop(CellEdit(ClassCell(
      course: _course.text.trim(),
      teacher: _teacher.text.trim(),
      room: _room.text.trim(),
      tough: _tough,
    )));
  }

  String? _errorFor(TextEditingController c) =>
      _showErrors && c.text.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit class'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            TextField(
              controller: _course,
              decoration: InputDecoration(
                labelText: 'Course',
                errorText: _errorFor(_course),
              ),
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(
                text: widget.initial?.teacher ?? '',
              ),
              optionsBuilder: (value) => widget.teachers.keys.where(
                (t) => t.toLowerCase().contains(value.text.toLowerCase()),
              ),
              fieldViewBuilder: (context, controller, focusNode, _) {
                _teacher = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Teacher'),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _room,
              decoration: InputDecoration(
                labelText: 'Room',
                errorText: _errorFor(_room),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tough period'),
              value: _tough,
              onChanged: (value) => setState(() => _tough = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const CellEdit(null)),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
