import 'dart:async';

import 'package:flutter/material.dart';

import '../alerts/build_ct_alerts.dart';
import '../alerts/scheduler.dart';
import '../data/ct_repo.dart';
import '../data/routine_repo.dart';
import '../model/ct.dart';
import '../model/routine.dart';
import '../model/today.dart';
import '../theme.dart';
import 'ct_editor.dart';
import 'grid_page.dart';
import 'settings_page.dart';
import 'sync_error.dart';

class HomePage extends StatefulWidget {
  final RoutineRepo repo;
  final CtRepo ctRepo;
  final Future<void> Function()? onSignOut;
  final AlertScheduler? scheduler;

  const HomePage({
    super.key,
    required this.repo,
    required this.ctRepo,
    this.onSignOut,
    this.scheduler,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Stream<Routine> _routine = widget.repo.watch();
  late final Stream<List<Ct>> _cts = widget.ctRepo.watch();
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    // Keeps the Now and Next cards current while the screen stays open.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    _askForPermissions();
  }

  Future<void> _askForPermissions() async {
    if (!await _scheduler.needsPermissions()) return;
    if (await _scheduler.isLocked() || !mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow class alerts'),
        content: const Text(
          'To wake your screen 5 minutes before class, ClasSync needs to send '
          'notifications, set exact alarms, and run without battery limits. '
          'Android will ask you for each one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed == true) await _scheduler.requestPermissions();
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  AlertScheduler get _scheduler => widget.scheduler ?? alertScheduler;

  // Alerts open this page on the lock screen, so editing needs an unlock first.
  Future<void> _editCt([Ct? ct]) async {
    if (!await _scheduler.unlock() || !mounted) return;
    final edit = await showCtEditor(context, initial: ct);
    if (edit == null) return;
    final saved = edit.ct;
    if (saved != null) {
      await widget.ctRepo.save(saved);
    } else if (ct != null) {
      await widget.ctRepo.delete(ct.id);
    }
  }

  Widget _ctSection() {
    return StreamBuilder<List<Ct>>(
      stream: _cts,
      builder: (context, snapshot) {
        // The list can outlive a CT's time while this screen stays open.
        final now = DateTime.now();
        final cts = (snapshot.data ?? const <Ct>[])
            .where((ct) => ct.at.isAfter(now))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upcoming CTs',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _editCt,
                    icon: const Icon(Icons.add),
                    label: const Text('Add CT'),
                  ),
                ],
              ),
            ),
            for (final ct in cts)
              Card(
                child: ListTile(
                  title: Text(
                    ct.room == null ? ct.course : '${ct.course} · ${ct.room}',
                  ),
                  subtitle: Text(formatCtTime(ct.at)),
                  onTap: () => _editCt(ct),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _open(Widget page) async {
    if (!await _scheduler.unlock() || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClasSync'),
        actions: [
          IconButton(
            tooltip: 'Week',
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: () => _open(GridPage(repo: widget.repo)),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _open(
              SettingsPage(repo: widget.repo, onSignOut: widget.onSignOut),
            ),
          ),
        ],
      ),
      body: StreamBuilder<Routine>(
        stream: _routine,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: SyncError());
          final r = snapshot.data;
          if (r == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final t = today(r, DateTime.now());
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SlotCard(label: 'Now', slot: t.now, empty: 'No class now'),
              _SlotCard(
                label: 'Next',
                slot: t.next,
                empty: t.isClassDay ? 'No more classes today' : 'No classes today',
              ),
              _ctSection(),
              if (t.isClassDay) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Today',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final (period, cell) in t.periods)
                  ListTile(
                    leading: Text('${period.start}\n${period.end}'),
                    title: Text(cell?.course ?? 'Gap'),
                    subtitle: cell == null
                        ? null
                        : Text(
                            [
                              if (cell.teacher.isNotEmpty) cell.teacher,
                              cell.room,
                            ].join(' · '),
                          ),
                    trailing: cell?.tough == true
                        ? const Icon(Icons.circle, color: toughColor, size: 14)
                        : null,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final String label, empty;
  final Slot? slot;

  const _SlotCard({
    required this.label,
    required this.slot,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final slot = this.slot;
    final tough = slot?.cell.tough ?? false;
    return Card(
      color: tough ? toughColor : null,
      child: DefaultTextStyle.merge(
        style: tough ? const TextStyle(color: Colors.black) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 4),
                Text(
                  slot?.cell.label ?? empty,
                  style: text.titleLarge?.copyWith(
                    color: tough ? Colors.black : null,
                  ),
                ),
                if (slot != null) Text('${slot.period.start}–${slot.period.end}'),
                if (tough) const Text('Snacks before the class.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
