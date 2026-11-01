import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../theme.dart';
import 'build_alerts.dart';

const _channelId = 'class_alerts';
const _testAlertId = 9999;
const _battery = MethodChannel('classync/battery');

/// The next time this weekday and minute occurs, strictly after [now].
tz.TZDateTime nextInstance(int weekday, int minuteOfDay, tz.TZDateTime now) {
  var date = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );
  while (date.weekday != weekday || !date.isAfter(now)) {
    date = tz.TZDateTime(
      now.location,
      date.year,
      date.month,
      date.day + 1,
      date.hour,
      date.minute,
    );
  }
  return date;
}

/// Local notifications on Android. Every method does nothing on web.
class AlertScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  // Routine updates can arrive close together. Run them in order so they don't interleave.
  Future<void> _queue = Future.value();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Class alerts',
        description: 'Next class and gap period reminders',
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
      ),
    );
  }

  NotificationDetails _details(String body, {bool tough = false}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Class alerts',
          importance: Importance.max,
          priority: Priority.max,
          playSound: false,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.reminder,
          styleInformation: BigTextStyleInformation(body),
          color: tough ? toughColor : null,
          colorized: tough,
        ),
      );

  // Without the exact alarm permission, alerts may run late but still arrive.
  Future<AndroidScheduleMode> _mode() async =>
      await _android?.canScheduleExactNotifications() == false
          ? AndroidScheduleMode.inexactAllowWhileIdle
          : AndroidScheduleMode.exactAllowWhileIdle;

  /// Replaces everything scheduled, so edited or removed classes leave no stale alert.
  Future<void> reschedule(List<Alert> alerts) {
    if (kIsWeb) return Future.value();
    return _queue = _queue.then((_) => _replaceAll(alerts)).catchError((Object e) {
      debugPrint('Could not schedule alerts: $e');
    });
  }

  Future<void> _replaceAll(List<Alert> alerts) async {
    await _plugin.cancelAll();
    final mode = await _mode();
    final now = tz.TZDateTime.now(tz.local);
    for (final alert in alerts) {
      await _plugin.zonedSchedule(
        id: alert.id,
        title: alert.title,
        body: alert.body,
        scheduledDate: nextInstance(alert.weekday, alert.minuteOfDay, now),
        notificationDetails: _details(alert.body, tough: alert.tough),
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Fires a sample alert in 10 seconds so the user can check it on their phone.
  Future<void> sendTest() async {
    if (kIsWeb) return;
    const body = '09:30';
    await _plugin.zonedSchedule(
      id: _testAlertId,
      title: 'DLD · ASD · 224',
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      notificationDetails: _details(body),
      androidScheduleMode: await _mode(),
    );
  }

  /// True when a permission alerts depend on is missing.
  Future<bool> needsPermissions() async {
    if (kIsWeb) return false;
    final android = _android;
    if (android == null) return false;
    return await android.areNotificationsEnabled() == false ||
        await android.canScheduleExactNotifications() == false ||
        await _battery.invokeMethod<bool>('isIgnoringBatteryOptimizations') == false;
  }

  /// Asks only for what is missing.
  Future<void> requestPermissions() async {
    final android = _android;
    if (kIsWeb || android == null) return;
    if (await android.areNotificationsEnabled() == false) {
      await android.requestNotificationsPermission();
    }
    await android.requestFullScreenIntentPermission();
    if (await android.canScheduleExactNotifications() == false) {
      await android.requestExactAlarmsPermission();
    }
    if (await _battery.invokeMethod<bool>('isIgnoringBatteryOptimizations') == false) {
      await _battery.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    }
  }
}

final alertScheduler = AlertScheduler();
