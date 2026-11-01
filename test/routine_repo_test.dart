import 'package:classync/data/routine_repo.dart';
import 'package:classync/model/routine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const last = Routine(
    accent: 'teal',
    days: ['Sun'],
    periods: [],
    teachers: {},
    cells: {},
  );

  test('seeds only when the server confirms there is no routine', () {
    expect(shouldSeed(exists: false, fromCache: false), isTrue);
    expect(shouldSeed(exists: false, fromCache: true), isFalse);
    expect(shouldSeed(exists: true, fromCache: false), isFalse);
    expect(shouldSeed(exists: true, fromCache: true), isFalse);
  });

  test('the bundled default routine is the class timetable', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final seed = await loadDefaultRoutine();
    expect(seed.days, ['Sun', 'Mon', 'Tue', 'Wed']);
    expect(seed.periods.length, 6);
    expect(seed.row('Sun')[1]!.course, 'DLD Lab');
    expect(seed.row('Sun')[1]!.tough, isTrue);
    expect(seed.row('Mon')[5]!.room, '223');
    expect(seed.row('Tue')[5], isNull);
    expect(seed.teachers['AI'], 'Arfanul Islam');
  });

  test('missing doc gives an empty routine', () {
    expect(decodeRoutine(null, last).days, isEmpty);
  });

  test('good doc is parsed', () {
    final decoded = decodeRoutine({
      'accent': 'pink',
      'days': ['Mon'],
      'periods': [],
      'updatedAt': 'ignored',
    }, last);
    expect(decoded.accent, 'pink');
    expect(decoded.days, ['Mon']);
  });

  test('bad doc keeps the last good routine', () {
    expect(decodeRoutine({'days': 'nope'}, last), same(last));
  });

  test('bad doc with nothing to fall back on is an error, not empty', () {
    expect(
      () => decodeRoutine({'days': 'nope'}, null),
      throwsA(isA<InvalidRoutine>()),
    );
  });
}
