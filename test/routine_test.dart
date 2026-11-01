import 'dart:convert';
import 'dart:io';

import 'package:classync/model/routine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('assets/default_routine.json').readAsStringSync())
        as Map<String, dynamic>;

Routine parsed() => Routine.parse(fixture()).$1!;

void expectInvalid(void Function(Map<String, dynamic> json) change) {
  final json = fixture();
  change(json);
  final (routine, errors) = Routine.parse(json);
  expect(routine, isNull);
  expect(errors, isNotEmpty);
}

void main() {
  test('parses fixture', () {
    final (routine, errors) = Routine.parse(fixture());
    expect(errors, isEmpty);
    expect(routine!.days, ['Sun', 'Mon', 'Tue', 'Wed']);
    expect(routine.cells['Sun']![3], isNull);
    expect(routine.cells['Mon']![0]!.tough, isTrue);
    expect(routine.cells['Sun']![0]!.tough, isFalse);
    expect(routine.cells['Sun']![1]!.room, '140');
    expect(routine.periods[0].startMinute, 9 * 60 + 30);
    expect(routine.teachers['SJ'], 'Sabiha Jahan');
  });

  test('round trips', () {
    final json = parsed().toJson();
    expect(Routine.parse(json).$1!.toJson(), json);
  });

  test('tough is omitted from json when false', () {
    final cell = parsed().toJson()['cells']['Sun'][0] as Map<String, dynamic>;
    expect(cell.containsKey('tough'), isFalse);
  });

  test('missing day row is empty', () {
    final json = fixture();
    (json['cells'] as Map).remove('Wed');
    final (routine, errors) = Routine.parse(json);
    expect(errors, isEmpty);
    expect(routine!.row('Wed'), List.filled(6, null));
  });

  test('unknown teacher initials allowed', () {
    final json = fixture();
    (json['cells']['Sun'][0] as Map)['teacher'] = 'ZZ';
    expect(Routine.parse(json).$2, isEmpty);
  });

  test('missing accent defaults to blue', () {
    final json = fixture()..remove('accent');
    expect(Routine.parse(json).$1!.accent, 'blue');
  });

  test('unknown accent becomes blue', () {
    final json = fixture()..['accent'] = 'neon';
    final (routine, errors) = Routine.parse(json);
    expect(errors, isEmpty);
    expect(routine!.accent, 'blue');
  });

  group('invalid file returns errors', () {
    test('unknown day', () => expectInvalid((j) => j['days'] = ['Funday']));
    test('duplicate day', () => expectInvalid((j) => j['days'] = ['Sun', 'Sun']));
    test('bad time', () => expectInvalid((j) => j['periods'][0]['start'] = '9:3'));
    test('hour out of range',
        () => expectInvalid((j) => j['periods'][0]['start'] = '25:00'));
    test('start after end',
        () => expectInvalid((j) => j['periods'][0]['end'] = '09:00'));
    test('periods out of order', () {
      expectInvalid((j) {
        final p = j['periods'] as List;
        final first = p.removeAt(0);
        p.add(first);
      });
    });
    test('row too short',
        () => expectInvalid((j) => (j['cells']['Sun'] as List).removeLast()));
    test('row for a day not listed',
        () => expectInvalid((j) => j['cells']['Fri'] = List.filled(6, null)));
    test('empty course',
        () => expectInvalid((j) => j['cells']['Sun'][0]['course'] = ''));
    test('empty room',
        () => expectInvalid((j) => j['cells']['Sun'][0]['room'] = ' '));
    test('days is the wrong type', () => expectInvalid((j) => j['days'] = 'Sun'));
    test('periods missing', () => expectInvalid((j) => j.remove('periods')));
    test('cell is the wrong type',
        () => expectInvalid((j) => j['cells']['Sun'][0] = 'DM'));
  });

  test('withPeriods pads and truncates rows', () {
    final r = parsed();
    final seven = r.withPeriods([...r.periods, const Period('15:00', '15:50')]);
    expect(seven.row('Sun').length, 7);
    expect(seven.row('Sun').last, isNull);
    expect(seven.row('Sun').sublist(0, 6), r.row('Sun'));
    final four = r.withPeriods(r.periods.sublist(0, 4));
    expect(four.row('Sun'), r.row('Sun').sublist(0, 4));
    expect(four.periods.length, 4);
  });

  test('withCell changes one cell only', () {
    final r = parsed();
    final changed =
        r.withCell('Sun', 3, const ClassCell(course: 'X', teacher: 'Y', room: 'Z'));
    expect(changed.row('Sun')[3]!.course, 'X');
    expect(changed.row('Sun')[0], r.row('Sun')[0]);
    expect(r.row('Sun')[3], isNull);
    expect(changed.withCell('Sun', 3, null).row('Sun')[3], isNull);
  });

  test('withCell works on a day with no row yet', () {
    final json = fixture();
    (json['cells'] as Map).remove('Wed');
    final r = Routine.parse(json).$1!;
    final changed = r.withCell(
        'Wed', 2, const ClassCell(course: 'X', teacher: 'Y', room: 'Z'));
    expect(changed.row('Wed').length, 6);
    expect(changed.row('Wed')[2]!.course, 'X');
  });

  test('withoutPeriod drops that column from every row', () {
    final r = parsed().withoutPeriod(1);
    expect(r.periods.length, 5);
    expect(r.periods[1].start, '11:20');
    expect(r.row('Sun')[1]!.course, 'STAT');
    expect(r.row('Tue').length, 5);
    expect(Routine.parse(r.toJson()).$2, isEmpty);
  });

  test('withDays drops rows of removed days and stays valid', () {
    final r = parsed().withDays(['Sun', 'Mon']);
    expect(r.cells.containsKey('Tue'), isFalse);
    expect(Routine.parse(r.toJson()).$2, isEmpty);
  });

  test('parseText reads good JSON', () {
    final text = File('assets/default_routine.json').readAsStringSync();
    expect(Routine.parseText(text).$1!.days.length, 4);
  });

  test('parseText rejects text that is not JSON', () {
    final (routine, errors) = Routine.parseText('{oops');
    expect(routine, isNull);
    expect(errors.single, contains('not valid JSON'));
  });

  test('parseText rejects JSON that is not an object', () {
    expect(Routine.parseText('[1, 2]').$1, isNull);
  });

  test('Routine.empty has no days', () {
    final r = Routine.empty();
    expect(r.days, isEmpty);
    expect(r.periods, isEmpty);
    expect(r.accent, 'blue');
  });
}
