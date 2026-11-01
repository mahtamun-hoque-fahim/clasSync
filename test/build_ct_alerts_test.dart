import 'package:classync/alerts/build_ct_alerts.dart';
import 'package:classync/model/ct.dart';
import 'package:flutter_test/flutter_test.dart';

Ct ct({
  DateTime? at,
  List<int> remindBefore = const [60],
  String? room = '224',
  String? note,
}) =>
    Ct(
      id: 'a',
      course: 'DLD',
      at: at ?? DateTime(2026, 11, 5, 9, 30),
      room: room,
      note: note,
      remindBefore: remindBefore,
    );

void main() {
  final now = DateTime(2026, 11, 3, 9, 0);

  test('one alert per reminder', () {
    final alerts = buildCtAlerts([ct(remindBefore: [1440, 60])], now);
    expect(alerts.map((a) => a.when), [
      DateTime(2026, 11, 4, 9, 30),
      DateTime(2026, 11, 5, 8, 30),
    ]);
  });

  test('past reminders skipped', () {
    final alerts = buildCtAlerts(
      [ct(at: DateTime(2026, 11, 3, 12, 0), remindBefore: [1440, 60])],
      now,
    );
    expect(alerts.single.when, DateTime(2026, 11, 3, 11, 0));
  });

  test('text with room and note', () {
    final alert = buildCtAlerts([ct(note: 'Chapter 3')], now).single;
    expect(alert.title, 'CT: DLD · 224');
    expect(alert.body, 'in 1 hour · Thu 5 Nov, 09:30\nChapter 3');
  });

  test('text without room or note', () {
    final alert = buildCtAlerts([ct(room: null)], now).single;
    expect(alert.title, 'CT: DLD');
    expect(alert.body, 'in 1 hour · Thu 5 Nov, 09:30');
  });

  test('blank room and note count as missing', () {
    final alert = buildCtAlerts([ct(room: ' ', note: '')], now).single;
    expect(alert.title, 'CT: DLD');
    expect(alert.body, 'in 1 hour · Thu 5 Nov, 09:30');
  });

  test('labels', () {
    expect(reminderLabel(5), '5 min');
    expect(reminderLabel(60), '1 hour');
    expect(reminderLabel(360), '6 hours');
    expect(reminderLabel(1440), '1 day');
    expect(reminderLabel(2880), '2 days');
    expect(reminderLabel(90), '1 hour 30 min');
    expect(reminderLabel(1500), '1 day 1 hour');
  });

  test('ids unique', () {
    final alerts = buildCtAlerts(
      [
        ct(remindBefore: [1440, 60]),
        ct(remindBefore: [1440, 60], at: DateTime(2026, 11, 6, 9, 30)),
      ],
      now,
    );
    final ids = alerts.map((a) => a.id).toList();
    expect(ids.length, 4);
    expect(ids.toSet().length, 4);
    expect(ids.every((id) => id >= 1000), isTrue);
  });

  test('expired', () {
    final past = ct(at: now.subtract(const Duration(minutes: 1)));
    final exactly = ct(at: now);
    final later = ct(at: now.add(const Duration(minutes: 1)));
    expect(expiredCts([past, exactly, later], now), [past, exactly]);
  });

  test('json round trip', () {
    final original = ct(note: 'Chapter 3', remindBefore: [1440, 60]);
    final copy = Ct.tryFromJson('a', original.toJson())!;
    expect(copy.course, 'DLD');
    expect(copy.at, original.at);
    expect(copy.room, '224');
    expect(copy.note, 'Chapter 3');
    expect(copy.remindBefore, [1440, 60]);
  });

  test('missing optional fields are fine', () {
    final copy = Ct.tryFromJson('a', {'course': 'DLD', 'at': 0});
    expect(copy!.remindBefore, isEmpty);
    expect(copy.room, isNull);
  });

  test('malformed docs are skipped, not read as expired', () {
    expect(Ct.tryFromJson('a', {'course': 'DLD'}), isNull);
    expect(Ct.tryFromJson('a', {'course': 'DLD', 'at': 'soon'}), isNull);
    expect(Ct.tryFromJson('a', {'at': 0}), isNull);
    expect(
      Ct.tryFromJson('a', {
        'course': 'DLD',
        'at': 0,
        'remindBefore': ['x'],
      }),
      isNull,
    );
    expect(Ct.tryFromJson('a', {'course': 'DLD', 'at': 0, 'room': 5}), isNull);
  });
}
