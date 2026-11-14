import 'dart:async';

import 'package:flutter/material.dart';

import '../alerts/build_ct_alerts.dart';
import '../alerts/scheduler.dart';
import '../data/ct_repo.dart';
import '../data/routine_repo.dart';
import '../model/ct.dart';
import '../model/now_state.dart';
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
  late final StreamSubscription<List<Ct>> _ctSub;
  List<Ct> _ctsData = const [];

  @override
  void initState() {
    super.initState();
    // Keeps the Now and Next cards current while the screen stays open.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    // The Now card reads the whole item list, so it lives at page level.
    _ctSub = _cts.listen(
      (cts) => setState(() => _ctsData = cts),
      onError: (_) {},
    );
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
    _ctSub.cancel();
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
    final now = DateTime.now();
    final cts = _ctsData
        .where((ct) => ct.at.isAfter(now))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
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
              subtitle: Text(
                '${ctKindLabel(ct.kind)} · ${formatCtTime(ct.at)}',
              ),
              onTap: () => _editCt(ct),
            ),
          ),
      ],
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
          final now = DateTime.now();
          final t = today(r, now);
          // The Now card walks the full state timeline: class, lab,
          // homecoming, home, incoming, day off, near, exam countdown.
          final state = nowState(r, _ctsData, now);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _StateCard(state: state, accent: r.accent),
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
                  _TodayRow(
                    period: period,
                    cell: cell,
                    live: isOnNow(period, cell, now),
                    accent: r.accent,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One row of today's timetable. The class that is running right now is filled
/// with the accent gradient, so the current slot stands out from the rest.
class _TodayRow extends StatelessWidget {
  final Period period;
  final ClassCell? cell;
  final bool live;
  final String accent;

  const _TodayRow({
    required this.period,
    required this.cell,
    required this.live,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cell = this.cell;
    // Ink over the accent comes from contrast, not from the scheme: the accent
    // fill is the raw swatch in both themes.
    final ink = live ? inkOnAccent(accentFill(accent)) : null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: live
            ? BoxDecoration(
                gradient: liveGradient(
                  accent,
                  Theme.of(context).colorScheme.surface,
                ),
              )
            : null,
        child: ListTile(
          textColor: ink,
          iconColor: ink,
          leading: Text(
            '${period.start}\n${period.end}',
            style: live ? TextStyle(color: ink!.withValues(alpha: 0.8)) : null,
          ),
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
      ),
    );
  }
}

/// The Now card, rebuilt on the reference: the whole card carries the accent
/// gradient (70% alpha over the surface melting into the full accent), the
/// state's white-gradient icon on the right, and the state's title and
/// subtitle on the left. Every state - class, lab, homecoming, home,
/// incoming, night before, day off, near, exam countdown - renders here.
///
/// Text presentation is at parity with the home-screen widget: pure black
/// ink on every line (no scheme-derived tones, no alpha tints), the same
/// type fractions of the card's real height, the 65/35 text/icon split, the
/// widget's padding, and its tight line gaps. Only the background differs -
/// the accent gradient instead of the widget's white card.
class _StateCard extends StatelessWidget {
  final NowState state;
  final String accent;

  const _StateCard({required this.state, required this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The card's own surface is explicit, so the gradient's 70% top stop
    // composites over exactly the tone the card sits on.
    return Card(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: liveGradient(accent, scheme.surfaceContainerLow),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            // Type parity with the widget: every size rides the card's
            // width, expressed through the widget's measured placed aspect
            // (313.5 x 121.5 dp on the reference phone), so the app card
            // scales exactly like the widget does on resize.
            final w = box.maxWidth.isFinite ? box.maxWidth : 328.0;
            final unit = w / 2.58;
            // The app card's ink: white on the accent gradient, per the
            // user's live feedback (the widget keeps its black ink on the
            // white card). Type runs 4% under the widget's dial here.
            const ink = Colors.white;
            return Padding(
              // Left inset only (corrected per the user: the earlier
              // "right" mention was meant to be left) plus the vertical
              // padding - the text column runs flush to the right edge.
              padding: const EdgeInsets.fromLTRB(21, 24, 0, 24),
              child: Row(
                children: [
                  Expanded(
                    flex: 65,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 0.143 * unit,
                            height: 1.15,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: state.title),
                            if (state.tail.isNotEmpty)
                              TextSpan(text: ' : ${state.tail}'),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 0.269 * unit,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        if (state.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            state.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 0.143 * unit,
                              height: 1.15,
                              color: ink,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 35,
                    child: Center(
                      child: Image.asset(
                        'assets/icons/png/${state.icon}.png',
                        width: 0.47 * 0.35 * w,
                        height: 0.47 * 0.35 * w,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final slot = this.slot;
    final tough = slot?.cell.tough ?? false;
    return Card(
      clipBehavior: Clip.antiAlias,
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
                style: text.titleLarge,
              ),
              if (slot != null) Text('${slot.period.start}–${slot.period.end}'),
              if (tough) const Text('Snacks before the class.'),
            ],
          ),
        ),
      ),
    );
  }
}
