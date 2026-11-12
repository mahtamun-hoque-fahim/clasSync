import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../alerts/scheduler.dart';
import '../data/routine_repo.dart';
import '../model/routine.dart';
import '../theme.dart';
import 'sync_error.dart';

class SettingsPage extends StatefulWidget {
  final RoutineRepo repo;
  final Future<void> Function()? onSignOut;

  const SettingsPage({super.key, required this.repo, this.onSignOut});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Stream<Routine> _routine = widget.repo.watch();

  /// A routine that fails to parse would be ignored on the next read, so never store one.
  Future<void> _save(Routine r) async {
    final errors = Routine.parse(r.toJson()).$2;
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errors.first)));
      return;
    }
    await widget.repo.save(r);
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _toggleDay(Routine r, String day) async {
    if (!r.days.contains(day)) {
      final days = validDays
          .where((d) => d == day || r.days.contains(d))
          .toList();
      return _save(r.withDays(days));
    }
    final confirmed = await _confirm(
      'Remove $day?',
      'All classes on $day will be deleted.',
      'Remove',
    );
    if (confirmed) {
      await _save(r.withDays(r.days.where((d) => d != day).toList()));
    }
  }

  Future<void> _addPeriod(Routine r) {
    final start = r.periods.isEmpty ? 9 * 60 : r.periods.last.endMinute + 5;
    return _save(r.withPeriods([
      ...r.periods,
      Period(_format(start), _format(start + 50)),
    ]));
  }

  Future<void> _removePeriod(Routine r, int index) async {
    final p = r.periods[index];
    final confirmed = await _confirm(
      'Remove ${p.start}–${p.end}?',
      'Classes in this period will be deleted on every day.',
      'Remove',
    );
    if (confirmed) await _save(r.withoutPeriod(index));
  }

  Future<void> _editTime(Routine r, int index, {required bool isStart}) async {
    final p = r.periods[index];
    final minute = isStart ? p.startMinute : p.endMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (picked == null) return;
    final time = _format(picked.hour * 60 + picked.minute);
    final periods = [...r.periods];
    periods[index] = isStart ? Period(time, p.end) : Period(p.start, time);
    await _save(r.copyWith(periods: periods));
  }

  Future<void> _editTeacher(Routine r, [String? initials]) async {
    // Not disposed here: the dialog still uses them while animating closed.
    final code = TextEditingController(text: initials);
    final name = TextEditingController(text: r.teachers[initials]);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initials == null ? 'Add teacher' : 'Edit teacher'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Initials'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final newCode = code.text.trim();
    final newName = name.text.trim();
    if (save != true || newCode.isEmpty) return;
    final teachers = {...r.teachers}..remove(initials);
    teachers[newCode] = newName;
    await _save(r.copyWith(teachers: teachers));
  }

  Future<void> _import() async {
    final imported = await showDialog<Routine>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (imported == null || !mounted) return;
    final confirmed = await _confirm(
      'Replace your routine?',
      'Your current routine will be replaced by the imported one.',
      'Replace',
    );
    if (confirmed) await _save(imported);
  }

  Future<void> _signOut() async {
    final confirmed = await _confirm(
      'Sign out?',
      'Alerts on this phone stop until you sign in again. Your routine stays saved.',
      'Sign out',
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await widget.onSignOut?.call();
  }

  void _export(Routine r) {
    final json = const JsonEncoder.withIndent('  ').convert(r.toJson());
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export JSON'),
        content: SingleChildScrollView(child: SelectableText(json)),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: json)),
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: StreamBuilder<Routine>(
        stream: _routine,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Importing again is the way out of a stored routine that can't be read.
            return ListView(
              children: [
                const SyncError(),
                Center(
                  child: FilledButton(
                    onPressed: _import,
                    child: const Text('Import JSON'),
                  ),
                ),
              ],
            );
          }
          final r = snapshot.data;
          if (r == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _heading(context, 'Accent color'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in swatches.entries)
                    Tooltip(
                      message: entry.key,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _save(r.copyWith(accent: entry.key)),
                        child: CircleAvatar(
                          backgroundColor: entry.value,
                          child: r.accent == entry.key
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              _heading(context, 'Theme'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'system',
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: 'light',
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {r.themeMode},
                onSelectionChanged: (selection) =>
                    _save(r.copyWith(themeMode: selection.first)),
              ),
              _heading(context, 'Mode'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'class',
                    label: Text('Class'),
                    icon: Icon(Icons.school_outlined),
                  ),
                  ButtonSegment(
                    value: 'exam',
                    label: Text('Exam'),
                    icon: Icon(Icons.event_note_outlined),
                  ),
                  ButtonSegment(
                    value: 'vacation',
                    label: Text('Vacation'),
                    icon: Icon(Icons.beach_access_outlined),
                  ),
                ],
                selected: {r.mode},
                onSelectionChanged: (selection) => _save(r.copyWith(
                  mode: selection.first,
                  // Leaving vacation clears its end date.
                  vacationEnd: selection.first == 'vacation' ? r.vacationEnd : null,
                )),
              ),
              if (r.mode == 'exam') ..._examSection(context, r),
              if (r.mode == 'vacation') ..._vacationSection(context, r),
              _heading(context, 'Class days'),
              Wrap(
                spacing: 8,
                children: [
                  for (final day in validDays)
                    FilterChip(
                      label: Text(day),
                      selected: r.days.contains(day),
                      onSelected: (_) => _toggleDay(r, day),
                    ),
                ],
              ),
              _heading(context, 'Periods'),
              for (var i = 0; i < r.periods.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      TextButton(
                        onPressed: () => _editTime(r, i, isStart: true),
                        child: Text(r.periods[i].start),
                      ),
                      const Text('–'),
                      TextButton(
                        onPressed: () => _editTime(r, i, isStart: false),
                        child: Text(r.periods[i].end),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove period ${i + 1}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removePeriod(r, i),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _addPeriod(r),
                  icon: const Icon(Icons.add),
                  label: const Text('Add period'),
                ),
              ),
              _heading(context, 'Teachers'),
              for (final entry in r.teachers.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                  onTap: () => _editTeacher(r, entry.key),
                  trailing: IconButton(
                    tooltip: 'Remove teacher ${entry.key}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _save(r.copyWith(
                      teachers: {...r.teachers}..remove(entry.key),
                    )),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _editTeacher(r),
                  icon: const Icon(Icons.add),
                  label: const Text('Add teacher'),
                ),
              ),
              if (!kIsWeb) ...[
                _heading(context, 'Alerts'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await alertScheduler.sendTest();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test alert coming in 10 seconds. Lock your phone.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Send test alert in 10 s'),
                  ),
                ),
              ],
              _heading(context, 'Backup and new semester'),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _import,
                    child: const Text('Import JSON'),
                  ),
                  OutlinedButton(
                    onPressed: () => _export(r),
                    child: const Text('Export JSON'),
                  ),
                ],
              ),
              if (widget.onSignOut != null) ...[
                _heading(context, 'Account'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Course names that exist anywhere in the routine grid, for the exam picker.
  List<String> _courseNames(Routine r) {
    final names = <String>{};
    r.cells.forEach((_, row) {
      for (final cell in row) {
        if (cell != null) names.add(cell.course);
      }
    });
    return names.toList()..sort();
  }

  List<Widget> _examSection(BuildContext context, Routine r) {
    final exams = [...r.exams]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : (a.time ?? '').compareTo(b.time ?? '');
      });
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Exam start time'),
        subtitle: Text(
          'Shared default, ${r.examTime}. An exam can carry its own time.',
        ),
        trailing: OutlinedButton(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _parseTime(r.examTime),
            );
            if (picked == null) return;
            await _save(r.copyWith(examTime: _format(picked.hour * 60 + picked.minute)));
          },
          child: Text(r.examTime),
        ),
      ),
      for (final exam in exams)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(exam.course),
          subtitle: Text(
            '${exam.date} · ${exam.time ?? '${r.examTime} (shared)'}',
          ),
          onTap: () async {
            final edit = await showDialog<Exam>(
              context: context,
              builder: (_) => _ExamDialog(
                initial: exam,
                courses: _courseNames(r),
              ),
            );
            if (edit == null) return;
            await _save(r.copyWith(
              exams: [for (final e in r.exams) if (e != exam) e, edit],
            ));
          },
          trailing: IconButton(
            tooltip: 'Remove ${exam.course}',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _save(r.copyWith(
              exams: [for (final e in r.exams) if (e != exam) e],
            )),
          ),
        ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final exam = await showDialog<Exam>(
                context: context,
                builder: (_) => _ExamDialog(courses: _courseNames(r)),
              );
              if (exam == null) return;
              await _save(r.copyWith(exams: [...r.exams, exam]));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add exam'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final exams2 = await showDialog<List<Exam>>(
                context: context,
                builder: (_) => const _ExamsImportDialog(),
              );
              if (exams2 == null) return;
              await _save(r.copyWith(exams: exams2));
            },
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste exams JSON'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _vacationSection(BuildContext context, Routine r) {
    final end = r.vacationEnd == null
        ? null
        : DateTime.parse(r.vacationEnd!);
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Vacation ends'),
        subtitle: Text(
          end == null
              ? 'Pick the last day off; class states resume the day after.'
              : 'Class states resume ${_formatDate(end.add(const Duration(days: 1)))}.',
        ),
        trailing: OutlinedButton(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: end ?? now,
              firstDate: now,
              lastDate: DateTime(now.year + 2),
            );
            if (picked == null) return;
            await _save(r.copyWith(vacationEnd: _formatDate(picked)));
          },
          child: Text(end == null ? 'Pick date' : _formatDate(end)),
        ),
      ),
    ];
  }

  Widget _heading(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

String _format(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

TimeOfDay _parseTime(String time) => TimeOfDay(
      hour: int.parse(time.substring(0, 2)),
      minute: int.parse(time.substring(3)),
    );

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Add or edit one exam. The course comes from the routine's own course
/// list; the time is optional and falls back to the shared exam time.
class _ExamDialog extends StatefulWidget {
  final Exam? initial;
  final List<String> courses;

  const _ExamDialog({this.initial, required this.courses});

  @override
  State<_ExamDialog> createState() => _ExamDialogState();
}

class _ExamDialogState extends State<_ExamDialog> {
  late final _courseField =
      TextEditingController(text: widget.initial?.course ?? '');
  late String? _course = widget.initial?.course;
  late String? _date = widget.initial?.date;
  late String? _ownTime = widget.initial?.time;
  bool _showErrors = false;

  @override
  void dispose() {
    _courseField.dispose();
    super.dispose();
  }

  DateTime get _dateValue => _date == null ? DateTime.now() : DateTime.parse(_date!);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateValue.isBefore(now) ? now : _dateValue,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = _formatDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final courses = widget.courses;
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add exam' : 'Edit exam'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (courses.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: courses.contains(_course) ? _course : null,
                decoration: InputDecoration(
                  labelText: 'Course',
                  errorText: _showErrors && _course == null ? 'Required' : null,
                ),
                items: [
                  for (final c in courses)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _course = v),
              )
            else
              TextField(
                controller: _courseField,
                decoration: InputDecoration(
                  labelText: 'Course',
                  errorText:
                      _showErrors && _courseField.text.trim().isEmpty
                          ? 'Required'
                          : null,
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(_date ?? 'Exam date'),
            ),
            if (_showErrors && _date == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Pick a date.'),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Own start time'),
              subtitle: Text(
                _ownTime == null ? 'Uses the shared exam time' : _ownTime!,
              ),
              value: _ownTime != null,
              onChanged: (on) async {
                if (!on) {
                  setState(() => _ownTime = null);
                  return;
                }
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _parseTime(_ownTime ?? '10:00'),
                );
                if (picked == null) return;
                setState(
                  () => _ownTime = _format(picked.hour * 60 + picked.minute),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final course = courses.isEmpty ? _courseField.text.trim() : _course;
            if (course == null || course.isEmpty || _date == null) {
              setState(() => _showErrors = true);
              return;
            }
            Navigator.of(context).pop(
              Exam(course: course, date: _date!, time: _ownTime),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Paste a bare list of exams, or a full routine JSON from which the "exams"
/// list is taken. Valid entries are kept; an empty result shows the errors.
class _ExamsImportDialog extends StatefulWidget {
  const _ExamsImportDialog();

  @override
  State<_ExamsImportDialog> createState() => _ExamsImportDialogState();
}

class _ExamsImportDialogState extends State<_ExamsImportDialog> {
  final _text = TextEditingController();
  List<String> _errors = [];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _import() {
    final List<dynamic> raw;
    try {
      final json = jsonDecode(_text.text);
      if (json is List) {
        raw = json;
      } else if (json is Map && json['exams'] is List) {
        raw = json['exams'] as List;
      } else {
        setState(() => _errors = ['Expected a list of exams, or routine JSON.']);
        return;
      }
    } on FormatException catch (e) {
      setState(() => _errors = ['This is not valid JSON: ${e.message}']);
      return;
    }
    final exams = <Exam>[];
    for (final entry in raw) {
      final exam = Exam.tryFromJson(entry);
      if (exam != null) exams.add(exam);
    }
    if (exams.isEmpty) {
      setState(
        () => _errors = ['No valid exams found in ${raw.length} entries.'],
      );
      return;
    }
    Navigator.of(context).pop(exams);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste exams JSON'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText:
                    '[{"course": "Math-3", "date": "2026-11-20"}]',
                alignLabelWithHint: true,
              ),
            ),
            for (final error in _errors)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _import, child: const Text('Import')),
      ],
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _text = TextEditingController();
  List<String> _errors = [];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    _text.text = utf8.decode(bytes, allowMalformed: true);
  }

  void _import() {
    final (routine, errors) = Routine.parseText(_text.text);
    if (routine != null) {
      Navigator.of(context).pop(routine);
    } else {
      setState(() => _errors = errors);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import JSON'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Paste JSON here',
                alignLabelWithHint: true,
              ),
            ),
            for (final error in _errors)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (kIsWeb)
          TextButton(onPressed: _chooseFile, child: const Text('Choose file')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _import, child: const Text('Import')),
      ],
    );
  }
}
