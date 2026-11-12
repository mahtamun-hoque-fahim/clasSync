import 'package:flutter/material.dart';

import '../alerts/build_ct_alerts.dart';
import '../model/ct.dart';

const _presets = [60, 360, 1440, 2880, 10080];
const _defaults = [1440, 360, 60];

/// What the editor returned. `ct` is null when the CT was deleted.
/// A null result from [showCtEditor] means cancelled.
class CtEdit {
  final Ct? ct;

  const CtEdit(this.ct);
}

Future<CtEdit?> showCtEditor(BuildContext context, {Ct? initial}) =>
    showDialog<CtEdit>(
      context: context,
      builder: (_) => _CtEditor(initial: initial),
    );

class _CtEditor extends StatefulWidget {
  final Ct? initial;

  const _CtEditor({this.initial});

  @override
  State<_CtEditor> createState() => _CtEditorState();
}

class _CtEditorState extends State<_CtEditor> {
  late final _course = TextEditingController(text: widget.initial?.course);
  late final _room = TextEditingController(text: widget.initial?.room);
  late final _note = TextEditingController(text: widget.initial?.note);
  late DateTime _at = widget.initial?.at ?? _tomorrowMorning();
  late String _kind = widget.initial?.kind ?? 'ct';
  late final Set<int> _reminders = {...?widget.initial?.remindBefore}.isNotEmpty
      ? {...widget.initial!.remindBefore}
      : {..._defaults};
  bool _showErrors = false;

  static DateTime _tomorrowMorning() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 9, 30);
  }

  @override
  void dispose() {
    _course.dispose();
    _room.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _at.isBefore(now) ? now : _at,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _at = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _at.hour,
          _at.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (picked != null) {
      setState(() {
        _at = DateTime(
          _at.year,
          _at.month,
          _at.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _addCustom() async {
    // Not disposed here: the dialog still uses it while animating closed.
    final field = TextEditingController();
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom reminder'),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes before'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(field.text.trim())),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (minutes != null && minutes > 0) {
      setState(() => _reminders.add(minutes));
    }
  }

  void _toggle(int minutes) => setState(() {
        if (!_reminders.remove(minutes)) _reminders.add(minutes);
      });

  bool get _isValid =>
      _course.text.trim().isNotEmpty &&
      _at.isAfter(DateTime.now()) &&
      _reminders.isNotEmpty;

  void _save() {
    if (!_isValid) {
      setState(() => _showErrors = true);
      return;
    }
    final room = _room.text.trim();
    final note = _note.text.trim();
    Navigator.of(context).pop(CtEdit(Ct(
      id: widget.initial?.id ?? '',
      course: _course.text.trim(),
      at: _at,
      room: room.isEmpty ? null : room,
      note: note.isEmpty ? null : note,
      kind: _kind,
      remindBefore: _reminders.toList()..sort((a, b) => b.compareTo(a)),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    final chips = {..._presets, ..._reminders}.toList()..sort();
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? 'Add ${ctKindLabel(_kind)}'
            : 'Edit ${ctKindLabel(widget.initial!.kind)}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            TextField(
              controller: _course,
              decoration: InputDecoration(
                labelText: 'Course',
                errorText: _showErrors && _course.text.trim().isEmpty
                    ? 'Required'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final kind in ctKinds)
                  ChoiceChip(
                    label: Text(ctKindLabel(kind)),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(formatCtTime(_at).split(',').first),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(TimeOfDay.fromDateTime(_at).format(context)),
            ),
            if (_showErrors && !_at.isAfter(DateTime.now()))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Pick a future date and time.', style: error),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _room,
              decoration: const InputDecoration(labelText: 'Room (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 16),
            Text('Remind me before', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final minutes in chips)
                  FilterChip(
                    label: Text(reminderLabel(minutes)),
                    selected: _reminders.contains(minutes),
                    onSelected: (_) => _toggle(minutes),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Custom'),
                  onPressed: _addCustom,
                ),
              ],
            ),
            if (_showErrors && _reminders.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Pick at least one reminder.', style: error),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const CtEdit(null)),
            child: const Text('Delete'),
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
