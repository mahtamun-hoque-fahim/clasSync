import 'routine.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String dayName(DateTime date) => _dayNames[date.weekday - 1];

class Slot {
  final Period period;
  final ClassCell cell;

  const Slot(this.period, this.cell);
}

class Today {
  final bool isClassDay;
  final Slot? now, next;
  final List<(Period, ClassCell?)> periods;

  const Today({
    required this.isClassDay,
    required this.now,
    required this.next,
    required this.periods,
  });
}

Today today(Routine r, DateTime time) {
  final day = dayName(time);
  if (!r.days.contains(day)) {
    return const Today(isClassDay: false, now: null, next: null, periods: []);
  }

  final minute = time.hour * 60 + time.minute;
  final row = r.row(day);
  Slot? now, next;
  for (var i = 0; i < row.length; i++) {
    final cell = row[i];
    final period = r.periods[i];
    if (cell == null) continue;
    if (period.startMinute <= minute && minute < period.endMinute) {
      now = Slot(period, cell);
    } else if (next == null &&
        period.startMinute > minute &&
        !cell.sameClass(now?.cell)) {
      next = Slot(period, cell);
    }
  }
  return Today(
    isClassDay: true,
    now: now,
    next: next,
    periods: [for (var i = 0; i < row.length; i++) (r.periods[i], row[i])],
  );
}
