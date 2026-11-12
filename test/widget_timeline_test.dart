import 'package:classync/model/ct.dart';
import 'package:classync/model/routine.dart';
import 'package:classync/widget/widget_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

Routine _routine({
  List<String> days = const ['Sun', 'Mon', 'Tue'],
  String mode = 'class',
  List<Exam> exams = const [],
  String examTime = '10:00',
}) =>
    Routine(
      accent: 'blue',
      mode: mode,
      days: days,
      periods: const [
        Period('09:30', '10:20'),
        Period('10:20', '11:10'),
        Period('11:15', '12:05'),
      ],
      teachers: const {},
      cells: {
        'Sun': const [
          ClassCell(course: 'Math-3', teacher: 'F', room: '101'),
          null,
          ClassCell(course: 'DLD LAB', teacher: 'G', room: '224'),
        ],
        'Mon': const [
          ClassCell(course: 'Math-3', teacher: 'F', room: '101'),
          ClassCell(course: 'Math-3', teacher: 'F', room: '101'),
          null,
        ],
        'Tue': const [null, null, null],
      },
      exams: exams,
      examTime: examTime,
    );

Ct _item(String kind, DateTime at) =>
    Ct(id: 'x', course: 'Math-3', at: at, kind: kind, remindBefore: const []);

/// Wed 2026-11-18, Sun 2026-11-22, Mon 2026-11-23, Tue 2026-11-24.
void main() {
  test('a class day carries theory, lab and homecoming boundaries', () {
    final days = widgetTimeline(_routine(), const []);
    // Sun: class 09:30, lab at 11:15, homecoming at 12:05+90 = 13:35,
    // home at 13:35+... wait 12:05+90 -> homecoming starts 12:05? The state
    // at 12:05 is homecoming (sinceEnd 0 < 90); it flips at +90 = 13:35.
    final sun = days['2026-11-22']!;
    // minute-of-day for 09:30 = 570.
    final kinds = sun.map((p) => p['t']).toSet();
    expect(kinds, containsAll(['Math-3', 'DLD LAB', 'Spider Man', 'Sweet Home']));
    // Boundaries are sorted and start the day.
    final minutes = sun.map((p) => p['m'] as int).toList();
    expect(minutes.first, 0);
    expect(minutes, [...minutes]..sort());
  });

  test('an empty day is a single day-off point', () {
    final days = widgetTimeline(_routine(), const []);
    final tue = days['2026-11-24']!;
    expect(tue, hasLength(1));
    expect(tue.single['t'], 'Day Off');
  });

  test('an item inside the two-day window turns the day off into Near', () {
    // CT on Fri 2026-11-20; Wed 18th is two days out: near all day.
    final days = widgetTimeline(
      _routine(),
      [_item('ct', DateTime(2026, 11, 20, 9))],
    );
    final wed = days['2026-11-18']!;
    expect(wed.single['s'], 'CT Near');
    // Tue 24th: the CT is long past, so the (empty-grid) day relaxes.
    final tue = days['2026-11-24']!;
    expect(tue.single['t'], 'Day Off');
  });

  test('exam mode gap days show the countdown, changing at midnight', () {
    // Exam on Wed 2026-11-25 (Fri/Sat never hold exams).
    final days = widgetTimeline(
      _routine(mode: 'exam', exams: const [Exam(course: 'Math-3', date: '2026-11-25')]),
      const [],
    );
    // Sun 22, Mon 23, Tue 24: pure gap days, one point each.
    expect(days['2026-11-22']!.single['t'], '3 Days Left');
    expect(days['2026-11-23']!.single['t'], '2 Days Left');
    final tue = days['2026-11-24']!;
    expect(tue.first['t'], '1 Day Left');
    // The last 24 h (from Tue 10:00) count hours instead.
    expect(
      tue.map((p) => p['t']).where((t) => (t as String).contains('Hours')),
      isNotEmpty,
    );
    final wed = days['2026-11-25']!;
    // Exam day morning: Today; after 10:00 the class timeline shows through.
    expect(wed.first['t'], 'Today');
    expect(wed[0]['m'], 0);
    // After the exam start, a non-class day falls back to its day-off card.
    final after = wed.where((p) => (p['m'] as int) >= 600).map((p) => p['t']);
    expect(after, contains('Day Off'));
  });

  test('under 24 h the countdown counts hours', () {
    final days = widgetTimeline(
      _routine(mode: 'exam', exams: const [Exam(course: 'Math-3', date: '2026-11-19')]),
      const [],
    );
    // Wed 18th evening: exam Thu 10:00. At 20:00 -> 14 hours.
    final wed = days['2026-11-18']!;
    final hours = wed.map((p) => p['t']).where((t) => (t as String).contains('Hours'));
    expect(hours, isNotEmpty);
  });

  test('the night-before state appears late on the eve of a day off', () {
    final days = widgetTimeline(_routine(), const []);
    // Mon 23rd: last class 11:10; night state at 11:10+90+180 = 15:40 = 940.
    final mon = days['2026-11-23']!;
    final night = mon.where((p) => p['t'] == 'Tomorrow');
    expect(night, isNotEmpty);
    expect(night.first['m'], 940);
  });
}
