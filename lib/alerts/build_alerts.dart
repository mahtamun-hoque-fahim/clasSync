import '../model/routine.dart';

const _weekdays = {
  'Mon': DateTime.monday,
  'Tue': DateTime.tuesday,
  'Wed': DateTime.wednesday,
  'Thu': DateTime.thursday,
  'Fri': DateTime.friday,
  'Sat': DateTime.saturday,
  'Sun': DateTime.sunday,
};

const _gapMinute = 8 * 60;
const _leadMinutes = 5;

class Alert {
  final int id, weekday, minuteOfDay;
  final String title, body;
  final bool tough;

  const Alert({
    required this.id,
    required this.weekday,
    required this.minuteOfDay,
    required this.title,
    required this.body,
    this.tough = false,
  });
}

/// The weekly alerts for a routine: one per class block, plus one gap reminder per day.
List<Alert> buildAlerts(Routine r) {
  final alerts = <Alert>[];
  for (final day in r.days) {
    final row = r.row(day);
    if (row.every((cell) => cell == null)) continue;
    final weekday = _weekdays[day]!;

    for (var i = 0; i < row.length; i++) {
      final cell = row[i];
      if (cell == null) continue;
      if (i > 0 && cell.sameClass(row[i - 1])) continue;

      var tough = cell.tough;
      for (var j = i + 1; j < row.length && cell.sameClass(row[j]); j++) {
        tough = tough || row[j]!.tough;
      }

      final start = r.periods[i];
      var minute = start.startMinute - _leadMinutes;
      var alertDay = weekday;
      if (minute < 0) {
        minute += 24 * 60;
        alertDay = weekday == DateTime.monday ? DateTime.sunday : weekday - 1;
      }
      alerts.add(Alert(
        id: weekday * 100 + i,
        weekday: alertDay,
        minuteOfDay: minute,
        title: cell.label,
        body: tough
            ? '${start.start}\nSnacks before the class.'
            : start.start,
        tough: tough,
      ));
    }

    final gaps = [
      for (var i = 0; i < row.length; i++)
        if (row[i] == null) '${r.periods[i].start}–${r.periods[i].end}',
    ];
    if (gaps.isNotEmpty) {
      final count =
          gaps.length == 1 ? '1 gap period' : '${gaps.length} gap periods';
      alerts.add(Alert(
        id: weekday * 100 + 99,
        weekday: weekday,
        minuteOfDay: _gapMinute,
        title: 'Gap periods today',
        body: '$count today: ${gaps.join(', ')}',
      ));
    }
  }
  return alerts;
}
