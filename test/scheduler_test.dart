import 'package:classync/alerts/build_alerts.dart';
import 'package:classync/alerts/build_ct_alerts.dart';
import 'package:classync/alerts/scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final calls = <String>[];
  final scheduled = <int>[];
  int? failOnId;

  @override
  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlatform>() => null;

  @override
  Future<void> cancelAll() async => calls.add('cancelAll');

  @override
  Future<void> cancelAllPendingNotifications() async =>
      calls.add('cancelPending');

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (id == failOnId) throw ArgumentError('date must be in the future');
    scheduled.add(id);
  }
}

void main() {
  tzdata.initializeTimeZones();
  final dhaka = tz.getLocation('Asia/Dhaka');

  group('AlertScheduler', () {
    const first = Alert(
      id: 1,
      weekday: DateTime.monday,
      minuteOfDay: 600,
      title: 't',
      body: 'b',
    );
    const second = Alert(
      id: 2,
      weekday: DateTime.tuesday,
      minuteOfDay: 600,
      title: 't',
      body: 'b',
    );
    final ct = CtAlert(
      id: 1000,
      when: DateTime.now().add(const Duration(days: 1)),
      title: 't',
      body: 'b',
    );

    setUp(() => tz.setLocalLocation(dhaka));

    test('rescheduling leaves notifications already showing', () async {
      final plugin = FakePlugin();
      await AlertScheduler(plugin).reschedule([first], [ct]);
      expect(plugin.calls, ['cancelPending']);
      expect(plugin.scheduled, [1, 1000]);
    });

    test('one failing alert does not drop the others', () async {
      final plugin = FakePlugin()..failOnId = 1;
      await AlertScheduler(plugin).reschedule([first, second], [ct]);
      expect(plugin.scheduled, [2, 1000]);
    });

    test('clear cancels pending alerts', () async {
      final plugin = FakePlugin();
      await AlertScheduler(plugin).clear();
      expect(plugin.calls, ['cancelPending']);
    });
  });

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
