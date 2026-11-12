import 'package:flutter_test/flutter_test.dart';

import 'package:classync/model/ct.dart';
import 'package:classync/model/routine.dart';

Routine _routine(Map<String, dynamic> extra) {
  final json = {
    'accent': 'blue',
    'days': ['Sun', 'Mon'],
    'periods': [
      {'start': '09:30', 'end': '10:20'},
    ],
    'teachers': {'F': 'Fahim'},
    'cells': {
      'Sun': [
        {'course': 'DLD LAB', 'teacher': 'F', 'room': '224'},
      ],
      'Mon': [null],
    },
    ...extra,
  };
  final (r, errors) = Routine.parse(json);
  expect(errors, isEmpty);
  return r!;
}

void main() {
  group('Ct kind', () {
    test('defaults to ct when the doc has no kind (old data)', () {
      final ct = Ct.tryFromJson('id', {
        'course': 'Math-3',
        'at': 1700000000000,
        'remindBefore': [30],
      });
      expect(ct!.kind, 'ct');
    });

    test('round-trips every kind', () {
      for (final kind in ctKinds) {
        final ct = Ct(
          id: 'id',
          course: 'DLD',
          at: DateTime(2026, 11, 15, 10),
          kind: kind,
          remindBefore: const [],
        );
        final back = Ct.tryFromJson('id', ct.toJson());
        expect(back!.kind, kind);
      }
    });

    test('rejects an unknown kind', () {
      final ct = Ct.tryFromJson('id', {
        'course': 'DLD',
        'at': 1700000000000,
        'kind': 'quiz',
        'remindBefore': const [],
      });
      expect(ct, isNull);
    });
  });

  group('Exam', () {
    test('parses a valid exam and keeps its own time', () {
      final e = Exam.tryFromJson({
        'course': 'Math-3',
        'date': '2026-11-20',
        'time': '14:00',
      });
      expect(e!.course, 'Math-3');
      expect(e.date, '2026-11-20');
      expect(e.time, '14:00');
    });

    test('drops malformed entries instead of throwing', () {
      expect(Exam.tryFromJson({'course': '', 'date': '2026-11-20'}), isNull);
      expect(Exam.tryFromJson({'course': 'Math', 'date': '20-11-2026'}), isNull);
      expect(Exam.tryFromJson({'course': 'Math', 'date': '2026-11-20', 'time': '9:0'}), isNull);
      expect(Exam.tryFromJson('not a map'), isNull);
    });
  });

  group('Routine mode and exams', () {
    test('old JSON parses as class mode with no exams', () {
      final r = _routine(const {});
      expect(r.mode, 'class');
      expect(r.exams, isEmpty);
      expect(r.examTime, '09:00');
      expect(r.vacationEnd, isNull);
    });

    test('exam mode round-trips exams, shared time and override', () {
      final r = _routine(const {
        'mode': 'exam',
        'examTime': '10:00',
        'exams': [
          {'course': 'Math-3', 'date': '2026-11-19'},
          {'course': 'DLD', 'date': '2026-11-23', 'time': '14:30'},
        ],
      });
      expect(r.mode, 'exam');
      expect(r.examTime, '10:00');
      expect(r.exams.length, 2);
      expect(r.exams[0].time, isNull);
      expect(r.exams[1].time, '14:30');

      final back = Routine.parse(r.toJson()).$1!;
      expect(back.mode, 'exam');
      expect(back.exams[1].time, '14:30');
    });

    test('vacation mode carries its end date, and class mode clears it', () {
      final r = _routine(const {'mode': 'vacation', 'vacationEnd': '2026-11-30'});
      expect(r.vacationEnd, '2026-11-30');
      final back = Routine.parse(r.toJson()).$1!;
      expect(back.vacationEnd, '2026-11-30');

      final cleared = r.copyWith(mode: 'class', vacationEnd: null);
      expect(cleared.vacationEnd, isNull);
      expect(cleared.mode, 'class');
    });

    test('exams are never held on Friday or Saturday', () {
      // 2026-11-13 is a Friday, 2026-11-14 a Saturday.
      for (final date in const ['2026-11-13', '2026-11-14']) {
        final (bad, errors) = Routine.parse({
          'days': ['Sun'],
          'periods': [
            {'start': '09:30', 'end': '10:20'},
          ],
          'mode': 'exam',
          'exams': [
            {'course': 'Math-3', 'date': date},
          ],
        });
        expect(bad, isNull);
        expect(errors.single, contains('never held on'));
      }
      // Weekday exams pass.
      final (ok, errors) = Routine.parse({
        'days': ['Sun'],
        'periods': [
          {'start': '09:30', 'end': '10:20'},
        ],
        'exams': [
          {'course': 'Math-3', 'date': '2026-11-16'},
        ],
      });
      expect(errors, isEmpty);
      expect(ok!.exams.single.date, '2026-11-16');
    });

    test('bad values fall back or fail loudly', () {
      // Unknown mode falls back to class rather than breaking the import.
      expect(_routine(const {'mode': 'chaos'}).mode, 'class');
      // Malformed exams are dropped, valid ones kept.
      final r = _routine(const {
        'mode': 'exam',
        'exams': [
          {'course': 'Good', 'date': '2026-11-19'},
          {'course': 'Bad', 'date': 'Nov 20'},
        ],
      });
      expect(r.exams.map((e) => e.course), ['Good']);
      // Malformed examTime is a hard error so the user sees it in the import.
      final (bad, errors) = Routine.parse({
        'days': ['Sun'],
        'periods': [
          {'start': '09:30', 'end': '10:20'},
        ],
        'examTime': 'ten',
      });
      expect(bad, isNull);
      expect(errors.single, contains('examTime'));
    });
  });
}
