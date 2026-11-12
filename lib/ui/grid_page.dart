import 'package:flutter/material.dart';

import '../data/routine_repo.dart';
import '../model/routine.dart';
import '../theme.dart';
import 'cell_editor.dart';
import 'sync_error.dart';

class GridPage extends StatefulWidget {
  final RoutineRepo repo;

  const GridPage({super.key, required this.repo});

  @override
  State<GridPage> createState() => _GridPageState();
}

class _GridPageState extends State<GridPage> {
  late final Stream<Routine> _routine = widget.repo.watch();

  Future<void> _edit(Routine r, String day, int period) async {
    final edit = await showCellEditor(
      context,
      initial: r.row(day)[period],
      teachers: r.teachers,
    );
    if (edit != null) await widget.repo.save(r.withCell(day, period, edit.cell));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Week')),
      body: StreamBuilder<Routine>(
        stream: _routine,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: SyncError());
          final r = snapshot.data;
          if (r == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (r.days.isEmpty || r.periods.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No routine yet. Add days and periods in Settings, or import a JSON file.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: _grid(context, r),
            ),
          );
        },
      ),
    );
  }

  Widget _grid(BuildContext context, Routine r) {
    final text = Theme.of(context).textTheme;
    return Table(
      defaultColumnWidth: const FixedColumnWidth(112),
      columnWidths: const {0: FixedColumnWidth(48)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          const SizedBox.shrink(),
          for (final p in r.periods)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                '${p.start}–${p.end}',
                style: text.labelSmall,
                textAlign: TextAlign.center,
              ),
            ),
        ]),
        for (final day in r.days)
          TableRow(children: [
            Text(day, style: text.titleSmall),
            for (var i = 0; i < r.periods.length; i++)
              _cell(context, r.accent, r.row(day)[i], () => _edit(r, day, i)),
          ]),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    String accent,
    ClassCell? cell,
    VoidCallback onTap,
  ) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // The accent cell is the raw swatch, never a pale container. Tough keeps
    // its amber. Ink follows the fill so text stays readable on any swatch.
    final fill =
        cell == null ? null : (cell.tough ? toughColor : accentFill(accent));
    final ink = fill == null ? null : inkOnAccent(fill);
    return Card(
      margin: const EdgeInsets.all(3),
      clipBehavior: Clip.antiAlias,
      color: fill ?? scheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Center(
            child: cell == null
                ? const Text('—')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cell.course,
                        style: text.titleSmall?.copyWith(color: ink),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          if (cell.teacher.isNotEmpty) cell.teacher,
                          cell.room,
                        ].join(' · '),
                        style: text.bodySmall?.copyWith(color: ink),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
