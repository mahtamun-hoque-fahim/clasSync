import '../model/ct.dart';
import '../model/now_state.dart';
import '../model/routine.dart';
import '../model/today.dart';

/// When the widget's state card changes appearance, as minute-of-day.
class StatePoint {
  final int minute;
  final NowState state;

  const StatePoint(this.minute, this.state);
}

/// Candidate minutes a day's card can flip on: class slot starts and ends,
/// the homecoming and night-before offsets after the last class, exam start
/// and each hour inside its last 24, and every scheduled item's own time.
Set<int> _candidates(Routine r, List<Ct> items, DateTime date) {
  int minuteOfDay(DateTime t) => t.hour * 60 + t.minute;
  bool sameDate(DateTime t) =>
      t.year == date.year && t.month == date.month && t.day == date.day;
  final out = <int>{0};

  final slots = daySlots(r, dayName(date));
  for (final slot in slots) {
    out.add(slot.period.startMinute);
    out.add(slot.period.endMinute);
  }
  if (slots.isNotEmpty) {
    final end = slots.last.period.endMinute;
    out.add(end + 90); // homecoming -> home
    out.add(end + 270); // home -> night before a day off
  }

  for (final exam in r.exams) {
    final start = examStart(r, exam, date);
    // The exam's own moment, plus every hour mark inside its last 24 h,
    // clipped into this day.
    final delta = start.difference(DateTime(date.year, date.month, date.day));
    for (var k = 0; k <= 24; k++) {
      final m = delta.inMinutes - k * 60;
      if (m > 0 && m < 1440) out.add(m);
    }
    if (sameDate(start)) out.add(minuteOfDay(start));
  }

  for (final item in items) {
    if (sameDate(item.at)) out.add(minuteOfDay(item.at));
  }
  return out;
}

/// The state card's change points for one date, in order. The state at
/// minute m is the last point with `minute <= m`.
List<StatePoint> dayTimeline(Routine r, List<Ct> items, DateTime date) {
  final minutes = _candidates(r, items, date).toList()..sort();
  final out = <StatePoint>[];
  for (final m in minutes) {
    final state = nowState(
      r,
      items,
      DateTime(date.year, date.month, date.day, m ~/ 60, m % 60),
    );
    // Only a change starts a new point; identical neighbours collapse.
    if (out.isEmpty || out.last.state.kind != state.kind || out.last.state.title != state.title) {
      out.add(StatePoint(m, state));
    }
  }
  return out;
}

/// Date-keyed timelines for the next [days] days, the widget's rendering
/// contract: states that depend on real dates (exam countdowns, near and
/// incoming windows) freeze into the snapshot, so the native provider can
/// render any moment without Dart.
Map<String, dynamic> widgetTimeline(Routine r, List<Ct> items, {int days = 21}) {
  final today = DateTime.now();
  final base = DateTime(today.year, today.month, today.day);
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return {
    for (var i = 0; i < days; i++)
      key(base.add(Duration(days: i))): [
        for (final p in dayTimeline(r, items, base.add(Duration(days: i))))
          {
            'm': p.minute,
            't': p.state.title,
            's': p.state.subtitle,
            'i': p.state.icon,
          },
      ],
  };
}
