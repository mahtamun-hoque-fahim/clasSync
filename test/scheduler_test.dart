import 'package:classync/alerts/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();
  final dhaka = tz.getLocation('Asia/Dhaka');
  // 2026-11-02 is a Monday.
  final now = tz.TZDateTime(dhaka, 2026, 11, 2, 10, 0);

  test('later today stays today', () {
    final next = nextInstance(DateTime.monday, 11 * 60, now);
    expect(next, tz.TZDateTime(dhaka, 2026, 11, 2, 11, 0));
  });

  test('earlier today moves to next week', () {
    final next = nextInstance(DateTime.monday, 9 * 60, now);
    expect(next, tz.TZDateTime(dhaka, 2026, 11, 9, 9, 0));
  });

  test('exactly now moves to next week', () {
    final next = nextInstance(DateTime.monday, 10 * 60, now);
    expect(next, tz.TZDateTime(dhaka, 2026, 11, 9, 10, 0));
  });

  test('another weekday lands on that weekday', () {
    final next = nextInstance(DateTime.sunday, 8 * 60, now);
    expect(next, tz.TZDateTime(dhaka, 2026, 11, 8, 8, 0));
    expect(next.weekday, DateTime.sunday);
  });

  test('a late alert keeps the right minute', () {
    final next = nextInstance(DateTime.tuesday, 1438, now);
    expect(next, tz.TZDateTime(dhaka, 2026, 11, 3, 23, 58));
  });
}
