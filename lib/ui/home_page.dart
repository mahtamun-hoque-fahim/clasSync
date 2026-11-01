import 'dart:async';

import 'package:flutter/material.dart';

import '../data/routine_repo.dart';
import '../model/routine.dart';
import '../model/today.dart';
import '../theme.dart';
import 'grid_page.dart';

class HomePage extends StatefulWidget {
  final RoutineRepo repo;

  const HomePage({super.key, required this.repo});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Stream<Routine> _routine = widget.repo.watch();
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    // Keeps the Now and Next cards current while the screen stays open.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _open(Widget page) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      );

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
        ],
      ),
      body: StreamBuilder<Routine>(
        stream: _routine,
        builder: (context, snapshot) {
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
