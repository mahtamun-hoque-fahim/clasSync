import 'dart:convert';
import 'dart:io';

import 'package:classync/model/routine.dart';
import 'package:classync/model/today.dart';
import 'package:flutter_test/flutter_test.dart';

Routine routine() => Routine.parse(
      jsonDecode(File('assets/default_routine.json').readAsStringSync())
          as Map<String, dynamic>,
    ).$1!;

// 2026-11-01 is a Sunday, 2026-11-02 a Monday.
void main() {
  test('dayName maps weekdays', () {
    expect(dayName(DateTime(2026, 11, 1)), 'Sun');
    expect(dayName(DateTime(2026, 11, 2)), 'Mon');
    expect(dayName(DateTime(2026, 11, 7)), 'Sat');
  });

  test('during a class shows it and the next one', () {
    final t = today(routine(), DateTime(2026, 11, 1, 9, 45));
    expect(t.now!.cell.course, 'DM');
    expect(t.next!.cell.course, 'DLD Lab');
  });

  test('before the first class only has a next', () {
    final t = today(routine(), DateTime(2026, 11, 1, 8, 0));
    expect(t.now, isNull);
    expect(t.next!.cell.course, 'DM');
  });

  test('next skips the rest of a double period', () {
    final t = today(routine(), DateTime(2026, 11, 2, 9, 45));
    expect(t.now!.cell.course, 'JAVA lab');
    expect(t.next!.cell.course, 'DM');
  });

  test('during a gap there is no now', () {
    final t = today(routine(), DateTime(2026, 11, 1, 12, 30));
    expect(t.now, isNull);
    expect(t.next!.cell.course, 'BE');
  });

  test('after the last class nothing is left', () {
    final t = today(routine(), DateTime(2026, 11, 1, 15, 0));
    expect(t.now, isNull);
    expect(t.next, isNull);
  });

  test('the same course after a gap still counts as next', () {
    // 2026-11-04 is a Wednesday: DLD in P1 and P2. Empty P2, DLD again in P3.
    final r = routine()
        .withCell('Wed', 1, null)
        .withCell('Wed', 2, routine().row('Wed')[0]);
    final t = today(r, DateTime(2026, 11, 4, 9, 45));
    expect(t.now!.cell.course, 'DLD');
    expect(t.next!.period.start, '11:20');
  });

  test('a class day lists every period', () {
    final t = today(routine(), DateTime(2026, 11, 1, 8, 0));
    expect(t.isClassDay, isTrue);
    expect(t.periods.length, 6);
    expect(t.periods[3].$2, isNull);
  });

  test('a day off is empty', () {
    final t = today(routine(), DateTime(2026, 11, 6, 10, 0));
    expect(t.isClassDay, isFalse);
    expect(t.now, isNull);
    expect(t.next, isNull);
  });
}
