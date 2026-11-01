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
}
