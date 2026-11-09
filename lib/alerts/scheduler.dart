import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../theme.dart';
import 'build_alerts.dart';
import 'build_ct_alerts.dart';

const _channelId = 'class_alerts';
const _testAlertId = 9999;
const _device = MethodChannel('classync/device');

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
  final FlutterLocalNotificationsPlugin _plugin;
  // Routine updates can arrive close together. Run them in order so they don't interleave.
  Future<void> _queue = Future.value();

  AlertScheduler([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (kIsWeb) return;
    // Called before runApp(), so nothing in here may throw: a bad resource or an
    // unsupported platform should degrade alerts, not leave a blank screen.
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          // Bare resource name: the plugin resolves it with
          // getIdentifier(name, "drawable", package) and rejects any prefix.
          android: AndroidInitializationSettings('ic_status'),
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
    } catch (e) {
      debugPrint('Could not initialise notifications: $e');
    }
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
  Future<void> reschedule(List<Alert> alerts, List<CtAlert> ctAlerts) {
    if (kIsWeb) return Future.value();
    return _queue = _queue
        .then((_) => _replaceAll(alerts, ctAlerts))
        .catchError((Object e) {
      debugPrint('Could not schedule alerts: $e');
    });
  }

  Future<void> _replaceAll(List<Alert> alerts, List<CtAlert> ctAlerts) async {
    // Pending only: cancelAll would also remove the alert the user is looking at.
    await _plugin.cancelAllPendingNotifications();
    final mode = await _mode();
    final now = tz.TZDateTime.now(tz.local);
    for (final alert in alerts) {
      await _scheduleSafely(
        id: alert.id,
        title: alert.title,
        body: alert.body,
        when: nextInstance(alert.weekday, alert.minuteOfDay, now),
        details: _details(alert.body, tough: alert.tough),
        mode: mode,
        repeat: DateTimeComponents.dayOfWeekAndTime,
      );
    }
    for (final alert in ctAlerts) {
      await _scheduleSafely(
        id: alert.id,
        title: alert.title,
        body: alert.body,
        when: tz.TZDateTime.from(alert.when, tz.local),
        details: _details(alert.body),
        mode: mode,
      );
    }
  }

  // One bad alert (say, a CT reminder that just came due) must not drop the rest.
  Future<void> _scheduleSafely({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required AndroidScheduleMode mode,
    DateTimeComponents? repeat,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: mode,
        matchDateTimeComponents: repeat,
      );
    } on Object catch (e) {
      debugPrint('Could not schedule alert $id: $e');
    }
  }

  /// Removes scheduled alerts, for sign-out.
  Future<void> clear() {
    if (kIsWeb) return Future.value();
    return _queue = _queue.then((_) => _plugin.cancelAllPendingNotifications());
  }

  /// True if the user may edit: not on the lock screen, or they just unlocked.
  Future<bool> unlock() async {
    if (kIsWeb || _android == null) return true;
    return await _device.invokeMethod<bool>('unlock') ?? false;
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
        await _device.invokeMethod<bool>('canUseFullScreenIntent') == false ||
        await _device.invokeMethod<bool>('isIgnoringBatteryOptimizations') == false;
  }

  Future<bool> isLocked() async {
    if (kIsWeb || _android == null) return false;
    return await _device.invokeMethod<bool>('isLocked') ?? false;
  }

  /// Asks only for what is missing.
  Future<void> requestPermissions() async {
    final android = _android;
    if (kIsWeb || android == null) return;
    if (await android.areNotificationsEnabled() == false) {
      await android.requestNotificationsPermission();
    }
    if (await _device.invokeMethod<bool>('canUseFullScreenIntent') == false) {
      await android.requestFullScreenIntentPermission();
    }
    if (await android.canScheduleExactNotifications() == false) {
      await android.requestExactAlarmsPermission();
    }
    if (await _device.invokeMethod<bool>('isIgnoringBatteryOptimizations') == false) {
      await _device.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    }
  }
}

final alertScheduler = AlertScheduler();
