import 'package:flutter_test/flutter_test.dart';

import 'package:classync/model/ct.dart';
import 'package:classync/model/now_state.dart';
import 'package:classync/model/routine.dart';

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

/// Wed 2026-11-18 (no class), Sun 2026-11-22, Mon 2026-11-23, Tue 2026-11-24.
void main() {
  group('class mode, class day (Sun: class, gap, lab)', () {
    final r = _routine();

    test('theory while the first class runs', () {
      final s = nowState(r, const [], DateTime(2026, 11, 22, 9, 45));
      expect(s.kind, 'theory');
      expect(s.label, 'Now');
      expect(s.title, 'Math-3');
      expect(s.tail, '101');
      // The lab later that day is the Next line.
      expect(s.subtitle, 'Next : DLD LAB . 224');
      expect(s.icon, 'grad_cap');
    });

    test('lab while the lab block runs, and merged slots keep it unbroken', () {
      // 10:20-11:10 is null (gap), the lab runs 11:15-12:05.
      final s = nowState(r, const [], DateTime(2026, 11, 22, 11, 30));
      expect(s.kind, 'lab');
      expect(s.icon, 'test_tube');
      expect(s.title, 'DLD LAB');
      expect(s.tail, '224');
    });

    test('before the first class shows the next class', () {
      final s = nowState(r, const [], DateTime(2026, 11, 22, 8, 0));
      expect(s.kind, 'theory');
      expect(s.subtitle, 'Starts 09:30');
    });

    test('homecoming runs 1.5 h after the last class ends', () {
      // Last class ends 12:05.
      final inside = nowState(r, const [], DateTime(2026, 11, 22, 13, 34));
      expect(inside.kind, 'homecoming');
      expect(inside.title, 'Spider Man');
      expect(inside.subtitle, 'Homecoming');
      expect(inside.icon, 'bus');

      final after = nowState(r, const [], DateTime(2026, 11, 22, 13, 36));
      expect(after.kind, 'home');
    });

    test('home with an item tomorrow becomes Incoming', () {
      final s = nowState(r, [_item('assignment', DateTime(2026, 11, 23, 17))],
          DateTime(2026, 11, 22, 15));
      expect(s.kind, 'incoming');
      expect(s.subtitle, 'Assignment Incoming');
      expect(s.icon, 'home_alert');
    });

    test('night before a day off, three hours into home', () {
      // Next day with classes after Sun is Mon (not a day off) -> plain home.
      final mon = nowState(r, const [], DateTime(2026, 11, 22, 20));
      expect(mon.kind, 'home');

      // Tue is empty (day off): Sun evening turns into the tomorrow card.
      final night = nowState(r, const [], DateTime(2026, 11, 23, 20, 30));
      // Mon's last class is 11:10; home starts 12:40; 3 h later is 15:40.
      expect(night.kind, 'nightBefore');
      expect(night.label, 'Tomorrow');
      expect(night.title, 'Day Off');
      expect(night.subtitle, 'Take a deep breath');
      expect(night.icon, 'plane_take_off');

      final early = nowState(r, const [], DateTime(2026, 11, 23, 15, 39));
      expect(early.kind, 'home');
    });

    test('Incoming wins over the night-before card', () {
      final s = nowState(r, [_item('ct', DateTime(2026, 11, 24, 9))],
          DateTime(2026, 11, 23, 20));
      expect(s.kind, 'incoming');
    });
  });

  group('class mode, non-class day (Wed)', () {
    final r = _routine();

    test('a day off just relaxes', () {
      final s = nowState(r, const [], DateTime(2026, 11, 18, 12));
      expect(s.kind, 'dayOff');
      expect(s.subtitle, 'Relaxing');
      expect(s.icon, 'plane');
    });

    test('an item within the next two days makes it Near', () {
      final ct = nowState(
          r, [_item('ct', DateTime(2026, 11, 20, 9))], DateTime(2026, 11, 18, 12));
      expect(ct.kind, 'near');
      expect(ct.subtitle, 'CT Near');
      expect(ct.icon, 'plane_take_off1');

      final lab = nowState(
          r, [_item('labReport', DateTime(2026, 11, 19, 9))], DateTime(2026, 11, 18, 8));
      expect(lab.subtitle, 'Lab Report Near');
    });

    test('an item three days out does not count', () {
      final s = nowState(
          r, [_item('ct', DateTime(2026, 11, 21, 9))], DateTime(2026, 11, 18, 12));
      expect(s.kind, 'dayOff');
    });
  });

  group('exam mode', () {
    test('gap day shows the countdown in days', () {
      final r = _routine(
        mode: 'exam',
        exams: const [Exam(course: 'Math-3', date: '2026-11-20')],
      );
      final s = nowState(r, const [], DateTime(2026, 11, 18, 12));
      expect(s.kind, 'examDays');
      expect(s.label, '2 Days Left');
      expect(s.title, 'Math-3 exam');
      expect(s.subtitle, '20-11-26');
      expect(s.icon, 'clipboard48');
    });

    test('under 24 h it counts hours', () {
      final r = _routine(
        mode: 'exam',
        exams: const [Exam(course: 'Math-3', date: '2026-11-19')],
      );
      final s = nowState(r, const [], DateTime(2026, 11, 18, 20));
      expect(s.kind, 'examHours');
      expect(s.label, '14 Hours Left');
      expect(s.title, 'Math-3 exam');
      expect(s.subtitle, '19-11-26');
      expect(s.icon, 'clipboard_arrow');
    });

    test('exam day says Today all morning, at the shared exam time', () {
      final r = _routine(
        mode: 'exam',
        exams: const [Exam(course: 'Math-3', date: '2026-11-19')],
      );
      final s = nowState(r, const [], DateTime(2026, 11, 19, 8));
      expect(s.kind, 'examToday');
      expect(s.label, 'Today');
      expect(s.title, 'Math-3 exam');
      expect(s.subtitle, '19-11-26');
      expect(s.icon, 'clipboard_check');
    });

    test('a per-exam time overrides the shared one', () {
      final r = _routine(
        mode: 'exam',
        examTime: '10:00',
        exams: const [Exam(course: 'DLD', date: '2026-11-19', time: '14:00')],
      );
      // 13:59 on exam day: one minute to the overridden 14:00 start -> Today.
      final s = nowState(r, const [], DateTime(2026, 11, 19, 13, 59));
      expect(s.kind, 'examToday');
    });

    test('after the exam time passes, the class timeline resumes', () {
      final r = _routine(
        mode: 'exam',
        exams: const [Exam(course: 'Math-3', date: '2026-11-22')],
      );
      // Sun 13:00: exam (10:00) passed, last class 12:05 -> homecoming window.
      final s = nowState(r, const [], DateTime(2026, 11, 22, 13));
      expect(s.kind, 'homecoming');
      // An hour later the window is over: home.
      final h = nowState(r, const [], DateTime(2026, 11, 22, 14));
      expect(h.kind, 'home');
    });

    test('day-off states are disabled in exam mode', () {
      final r = _routine(
        mode: 'exam',
        days: const ['Sun', 'Mon'],
        exams: const [Exam(course: 'Math-3', date: '2026-11-25')],
      );
      // Wed would be a relaxing Day Off in class mode; exam mode counts.
      final s = nowState(r, const [], DateTime(2026, 11, 23, 12));
      expect(s.kind, 'examDays');
      expect(s.label, '2 Days Left');
    });

    test('exam mode with nothing entered falls back to class states', () {
      final r = _routine(mode: 'exam');
      final s = nowState(r, const [], DateTime(2026, 11, 22, 9, 45));
      expect(s.kind, 'theory');
    });
  });

  group('vacation mode', () {
    test('always day-off states, class states gone', () {
      final r = _routine(mode: 'vacation');
      // Sun 09:45 would be a running class; vacation ignores it.
      final s = nowState(r, const [], DateTime(2026, 11, 22, 9, 45));
      expect(s.kind, 'dayOff');
    });

    test('items within two days still surface as Near', () {
      final r = _routine(mode: 'vacation');
      final s = nowState(r, [_item('presentation', DateTime(2026, 11, 24, 9))],
          DateTime(2026, 11, 22, 10));
      expect(s.kind, 'near');
      expect(s.subtitle, 'Presentation Near');
    });
  });
}
