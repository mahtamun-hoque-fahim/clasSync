import 'dart:convert';
import 'dart:io';

import 'package:classync/alerts/build_alerts.dart';
import 'package:classync/model/routine.dart';
import 'package:flutter_test/flutter_test.dart';

Routine routine() => Routine.parse(
      jsonDecode(File('assets/default_routine.json').readAsStringSync())
          as Map<String, dynamic>,
    ).$1!;

List<Alert> on(List<Alert> alerts, int weekday) =>
    alerts.where((a) => a.weekday == weekday).toList();

void main() {
  test('sunday first alert', () {
    final first = on(buildAlerts(routine()), DateTime.sunday)
        .firstWhere((a) => a.title == 'DM · SJ · 121');
    expect(first.minuteOfDay, 9 * 60 + 25);
    expect(first.body, '09:30');
    expect(first.tough, isFalse);
  });

  test('lab block merged', () {
    final monday = on(buildAlerts(routine()), DateTime.monday);
    final lab = monday.where((a) => a.title == 'JAVA lab · MA · 121').toList();
    expect(lab.length, 1);
    expect(lab.single.minuteOfDay, 9 * 60 + 25);
    expect(monday.any((a) => a.minuteOfDay == 10 * 60 + 20), isFalse);
  });

  test('same course in a different room is not merged', () {
    final r = routine().withCell(
      'Wed',
      1,
      const ClassCell(course: 'DLD', teacher: 'ASD', room: '999'),
    );
    final dld = on(buildAlerts(r), DateTime.wednesday)
        .where((a) => a.title.startsWith('DLD'))
        .toList();
    expect(dld.length, 2);
  });

  test('tough body', () {
    final lab = on(buildAlerts(routine()), DateTime.monday)
        .firstWhere((a) => a.title == 'JAVA lab · MA · 121');
    expect(lab.body, '09:30\nSnacks before the class.');
    expect(lab.tough, isTrue);
  });

  test('sunday gap', () {
    final gap = on(buildAlerts(routine()), DateTime.sunday)
        .firstWhere((a) => a.minuteOfDay == 480);
    expect(gap.title, 'Gap periods today');
    expect(gap.body, '1 gap period today: 12:15–13:05');
  });

  test('tuesday trailing gaps counted', () {
    final gap = on(buildAlerts(routine()), DateTime.tuesday)
        .firstWhere((a) => a.minuteOfDay == 480);
    expect(gap.body, '2 gap periods today: 13:10–14:00, 14:05–14:55');
  });

  test('leading gaps counted', () {
    final r = routine().withCell('Wed', 0, null);
    final gap = on(buildAlerts(r), DateTime.wednesday)
        .firstWhere((a) => a.minuteOfDay == 480);
    expect(gap.body, '1 gap period today: 09:30–10:20');
  });

  test('wednesday no gap alert', () {
    expect(
      on(buildAlerts(routine()), DateTime.wednesday)
          .where((a) => a.minuteOfDay == 480),
      isEmpty,
    );
  });

  test('off days silent', () {
    final alerts = buildAlerts(routine());
    expect(on(alerts, DateTime.thursday), isEmpty);
    expect(on(alerts, DateTime.friday), isEmpty);
    expect(on(alerts, DateTime.saturday), isEmpty);
  });

  test('all-empty class day silent', () {
    var r = routine();
    for (var i = 0; i < 6; i++) {
      r = r.withCell('Tue', i, null);
    }
    expect(on(buildAlerts(r), DateTime.tuesday), isEmpty);
  });

  test('ids are unique and stable', () {
    final ids = buildAlerts(routine()).map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(buildAlerts(routine()).map((a) => a.id).toList(), ids);
  });

  test('wraps before midnight', () {
    final r = Routine.parse({
      'days': ['Mon'],
      'periods': [
        {'start': '00:03', 'end': '00:50'},
      ],
      'cells': {
        'Mon': [
          {'course': 'X', 'teacher': 'Y', 'room': 'Z'},
        ],
      },
    }).$1!;
    final alert = buildAlerts(r).single;
    expect(alert.weekday, DateTime.sunday);
    expect(alert.minuteOfDay, 1438);
  });

  test('wrap from sunday lands on saturday', () {
    final r = Routine.parse({
      'days': ['Sun'],
      'periods': [
        {'start': '00:03', 'end': '00:50'},
      ],
      'cells': {
        'Sun': [
          {'course': 'X', 'teacher': 'Y', 'room': 'Z'},
        ],
      },
    }).$1!;
    expect(buildAlerts(r).single.weekday, DateTime.saturday);
  });

  test('empty teacher is left out of the title', () {
    final r = routine().withCell(
      'Wed',
      4,
      const ClassCell(course: 'JAVA', teacher: '', room: '220'),
    );
    final titles = on(buildAlerts(r), DateTime.wednesday).map((a) => a.title);
    expect(titles, contains('JAVA · 220'));
  });

  test('empty routine has no alerts', () {
    expect(buildAlerts(Routine.empty()), isEmpty);
  });
}

