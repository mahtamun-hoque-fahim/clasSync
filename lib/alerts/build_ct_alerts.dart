import '../model/ct.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class CtAlert {
  final int id;
  final DateTime when;
  final String title, body;

  const CtAlert({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });
}

/// `1 day`, `6 hours`, `1 hour 30 min`.
String reminderLabel(int minutes) {
  final days = minutes ~/ 1440;
  final hours = minutes % 1440 ~/ 60;
  final rest = minutes % 60;
  return [
    if (days > 0) days == 1 ? '1 day' : '$days days',
    if (hours > 0) hours == 1 ? '1 hour' : '$hours hours',
    if (rest > 0) '$rest min',
  ].join(' ');
}

String formatCtTime(DateTime at) {
  final hour = at.hour.toString().padLeft(2, '0');
  final minute = at.minute.toString().padLeft(2, '0');
  return '${_weekdays[at.weekday - 1]} ${at.day} ${_months[at.month - 1]}, '
      '$hour:$minute';
}

/// One-off alerts for upcoming reminders. Ids start at 1000, above every class alert id.
/// They only need to be unique per call, as rescheduling cancels everything first.
List<CtAlert> buildCtAlerts(List<Ct> cts, DateTime now) {
  final alerts = <CtAlert>[];
  for (final ct in cts) {
    final room = ct.room?.trim() ?? '';
    final note = ct.note?.trim() ?? '';
    for (final minutes in ct.remindBefore) {
      final when = ct.at.subtract(Duration(minutes: minutes));
      if (!when.isAfter(now)) continue;
      alerts.add(CtAlert(
        id: 1000 + alerts.length,
        when: when,
        title: room.isEmpty ? 'CT: ${ct.course}' : 'CT: ${ct.course} · $room',
        body: [
          'in ${reminderLabel(minutes)} · ${formatCtTime(ct.at)}',
          if (note.isNotEmpty) note,
        ].join('\n'),
      ));
    }
  }
  return alerts;
}

List<Ct> expiredCts(List<Ct> cts, DateTime now) =>
    cts.where((ct) => !ct.at.isAfter(now)).toList();
