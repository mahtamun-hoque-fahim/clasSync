import 'package:classync/alerts/alert_sync.dart';
import 'package:classync/alerts/build_alerts.dart';
import 'package:classync/alerts/build_ct_alerts.dart';
import 'package:classync/model/ct.dart';
import 'package:classync/model/routine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(List<Alert>, List<CtAlert>)> runs;
  late AlertSync sync;

  setUp(() {
    runs = [];
    sync = AlertSync((alerts, cts) => runs.add((alerts, cts)));
  });

  test('waits for both the routine and the CTs', () {
    sync.routine = Routine.empty();
    expect(runs, isEmpty);
    sync.cts = const [];
    expect(runs.length, 1);
  });

  test('refresh before both arrive does nothing', () {
    sync.routine = Routine.empty();
    sync.refresh();
    expect(runs, isEmpty);
  });

  test('refresh schedules again, as a permission may have changed', () {
    sync.routine = Routine.empty();
    sync.cts = const [];
    sync.refresh();
    expect(runs.length, 2);
  });

  test('CT reminders already past are left out', () {
    final soon = DateTime.now().add(const Duration(minutes: 90));
    sync.routine = Routine.empty();
    sync.cts = [
      Ct(id: 'a', course: 'DLD', at: soon, remindBefore: const [60, 120]),
    ];
    expect(runs.single.$2.length, 1);
  });
}
