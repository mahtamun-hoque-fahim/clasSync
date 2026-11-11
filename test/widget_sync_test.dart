import 'dart:convert';

import 'package:classync/model/routine.dart';
import 'package:classync/widget/widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

Routine _routine(Map<String, List<ClassCell?>> cells, {String accent = 'teal'}) {
  final periods = [
    const Period('09:30', '10:20'),
    const Period('10:25', '11:15'),
    const Period('11:20', '12:10'),
  ];
  final cellsWithPeriod = {
    for (final entry in cells.entries)
      if (validDays.contains(entry.key))
        entry.key: [
          ...entry.value,
          for (var i = entry.value.length; i < periods.length; i++) null,
        ],
  };
  return Routine(
    accent: accent,
    days: cellsWithPeriod.keys.toList(),
    periods: periods,
    teachers: const {'SJ': 'Sabiha Jahan', 'ZZ': 'Unknown'},
    cells: cellsWithPeriod,
  );
}

const dm1 = ClassCell(course: 'DM', teacher: 'SJ', room: '140');
const dm2 = ClassCell(course: 'DM', teacher: 'SJ', room: '140');
const stat = ClassCell(course: 'STAT', teacher: 'SJ', room: '342');

void main() {
  test('adjacent same-class periods merge into one slot', () {
    final slots = widgetSlots(_routine({'Sun': [dm1, dm2, null]}), 'Sun');
    expect(slots, hasLength(1));
    expect(slots.single.period.start, '09:30');
    expect(slots.single.period.end, '11:15');
    expect(slots.single.cell.course, 'DM');
  });

  test('same course in a different room does not merge', () {
    final slots = widgetSlots(
      _routine({'Sun': [dm1, const ClassCell(course: 'DM', teacher: 'SJ', room: '342'), null]}),
      'Sun',
    );
    expect(slots, hasLength(2));
  });

  test('free periods are skipped and order is preserved', () {
    final slots = widgetSlots(_routine({'Sun': [dm1, null, stat]}), 'Sun');
    expect(slots.map((s) => s.cell.course), ['DM', 'STAT']);
    expect(slots.map((s) => s.period.start), ['09:30', '11:20']);
  });

  test('a day with no row is empty', () {
    final slots = widgetSlots(_routine({'Sun': [dm1]}), 'Mon');
    expect(slots, isEmpty);
  });

  test('snapshot lists every valid day and only carries scheduled cells', () {
    final snapshot = widgetSnapshot(
      _routine({'Sun': [dm1, dm2, null], 'Mon': [null, stat, null]}),
    );
    expect((snapshot['days'] as Map)['Sun'], [
      {'s': '09:30', 'e': '11:15', 'c': 'DM', 't': 'SJ', 'r': '140'},
    ]);
    expect((snapshot['days'] as Map)['Mon'], [
      {'s': '10:25', 'e': '11:15', 'c': 'STAT', 't': 'SJ', 'r': '342'},
    ]);
    expect((snapshot['days'] as Map).keys, validDays);
    expect((snapshot['days'] as Map)['Tue'], isEmpty);
  });

  test('snapshot is valid JSON and carries both Material 3 palettes', () {
    final snapshot = widgetSnapshot(_routine({'Sun': [dm1]}, accent: 'teal'));
    final decoded = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    final light = decoded['palette']['light'] as Map<String, dynamic>;
    final dark = decoded['palette']['dark'] as Map<String, dynamic>;
    for (final mode in [light, dark]) {
      expect(mode['bg'], startsWith('#'));
      expect(mode['onBg'], startsWith('#'));
      expect(mode['dim'], startsWith('#'));
      expect(mode['accent'], startsWith('#'));
    }
    // Dark must be the app's soft M3 dark surface, never pure black.
    expect(dark['bg'], isNot('#000000'));
    expect(dark['bg'], isNot(light['bg']));
    // Merge loop must not have consumed periods greedily: three periods remain.
    expect(decoded['days']['Sun'], hasLength(1));
  });

  test('unknown accent falls back to blue', () {
    final routine = Routine(
      accent: 'neon',
      days: const [],
      periods: const [],
      teachers: const {},
      cells: const {},
    );
    expect(
      widgetSnapshot(routine)['palette'],
      widgetSnapshot(
        Routine(
          accent: 'blue',
          days: const [],
          periods: const [],
          teachers: const {},
          cells: const {},
        ),
      )['palette'],
    );
  });

  test('snapshot carries the theme-mode override', () {
    final system = _routine({'Sun': [dm1]});
    expect(widgetSnapshot(system)['theme'], 'system');
    expect(widgetSnapshot(system.copyWith(themeMode: 'dark'))['theme'], 'dark');
  });
}
