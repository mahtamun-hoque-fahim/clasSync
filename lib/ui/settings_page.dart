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
