import 'ct.dart';
import 'routine.dart';

/// How long after the last class ends the homecoming state runs.
const _homecomingMinutes = 90;

/// How long after home begins the night-before-day-off state takes over.
const _nightAfterHomeMinutes = 180;

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _dayName(DateTime d) => _dayNames[d.weekday - 1];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [from] to [to], ignoring clock time.
int _calendarDays(DateTime from, DateTime to) =>
    _dateOnly(to).difference(_dateOnly(from)).inDays;

/// Lab detection: the routine marks labs by name ("DLD LAB").
bool _isLab(String course) => course.toLowerCase().contains('lab');

/// One full card state: what the app's Now card and the home-screen widget
/// both render, as the reference layout's three lines. [label] is the small
/// first line ("Now", "Tomorrow", "Today", a countdown), [title] the big
/// bold line and [tail] its accent-colored part (the room in
/// "DLD LAB : 220"), [subtitle] the third line. [icon] is an asset key from
/// `assets/icons`.
class NowState {
  final String kind;
  final String label, title, tail, subtitle, icon;

  const NowState(
    this.kind,
    this.label,
    this.title,
    this.subtitle,
    this.icon, {
    this.tail = '',
  });
}

/// A merged run of adjacent periods holding the same class, matching how
/// build_alerts merges lab blocks: one unbroken slot, first period's start.
class NowSlot {
  final Period period;
  final ClassCell cell;
  const NowSlot(this.period, this.cell);
}

/// The day's merged class slots, in period order.
List<NowSlot> daySlots(Routine r, String day) {
  final row = r.row(day);
  final out = <NowSlot>[];
  for (var i = 0; i < row.length; i++) {
    final cell = row[i];
    if (cell == null) continue;
    final period = r.periods[i];
    final last = out.isEmpty ? null : out.last;
    if (last != null &&
        last.period.endMinute == period.startMinute &&
        last.cell.sameClass(cell)) {
      out[out.length - 1] = NowSlot(
        Period(last.period.start, period.end),
        last.cell,
      );
    } else {
      out.add(NowSlot(period, cell));
    }
  }
  return out;
}

int _minuteOf(DateTime t) => t.hour * 60 + t.minute;

/// The next scheduled item still in the future, or null.
Ct? _nextItem(List<Ct> items, DateTime now) {
  Ct? best;
  for (final item in items) {
    if (item.at.isAfter(now) && (best == null || item.at.isBefore(best.at))) {
      best = item;
    }
  }
  return best;
}

/// The exam's absolute start moment: its date at its own time, or the
/// routine's shared exam time.
DateTime examStart(Routine r, Exam e, DateTime now) {
  final date = DateTime.parse(e.date);
  final time = e.time ?? r.examTime;
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(time.substring(0, 2)),
    int.parse(time.substring(3)),
  );
}

/// The exam card's third line: the date as dd-MM-yy ("30-02-26").
String _examDate(Exam e) {
  final d = DateTime.parse(e.date);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${two(d.year % 100)}';
}

/// The full state for one moment, shared by the app's Now card and the
/// widget. Class mode walks the class-day timeline (theory/lab -> homecoming
/// -> home/incoming -> night before a day off) and the day-off states;
/// exam mode swaps class states for exam countdowns and disables day-off
/// states; vacation mode is a day-off period that only shows the day-off
/// states.
NowState nowState(Routine r, List<Ct> items, DateTime now) {
  if (r.mode == 'vacation') return _dayOffState(items, now);
  return switch (r.mode) {
    'exam' => _examMode(r, items, now),
    _ => _classMode(r, items, now),
  };
}

// --- class mode -----------------------------------------------------------

NowState _classMode(Routine r, List<Ct> items, DateTime now) {
  final day = _dayName(now);
  final slots = daySlots(r, day);
  final minute = _minuteOf(now);

  if (r.days.contains(day)) {
    // A class running right now.
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s.period.startMinute <= minute && minute < s.period.endMinute) {
        return _classNow(s, i + 1 < slots.length ? slots[i + 1] : null);
      }
    }
    // Classes still ahead today: show the next one.
    final next = slots.where((s) => s.period.startMinute > minute).toList();
    if (next.isNotEmpty) {
      final s = next.first;
      final isLab = _isLab(s.cell.course);
      return NowState(
        isLab ? 'lab' : 'theory',
        'Now',
        s.cell.course,
        'Starts ${s.period.start}',
        isLab ? 'test_tube' : 'grad_cap',
        tail: s.cell.room,
      );
    }
    // All of today's classes are over: homecoming, then home.
    if (slots.isNotEmpty) {
      final lastEnd = slots.last.period.endMinute;
      final sinceEnd = minute - lastEnd;
      if (sinceEnd < _homecomingMinutes) {
        return const NowState('homecoming', 'Now', 'Spider Man', 'Homecoming', 'bus');
      }
      // Home. An item today (later) or tomorrow becomes the card's subtitle.
      final incoming = _incomingLabel(items, now, maxDays: 1);
      if (incoming != null) {
        return NowState('incoming', 'Now', 'Home', '$incoming Incoming', 'home_alert');
      }
      // Three hours into home on the eve of a day off: tomorrow's card.
      if (_tomorrowIsDayOff(r, now) &&
          sinceEnd >= _homecomingMinutes + _nightAfterHomeMinutes) {
        return const NowState(
          'nightBefore',
          'Tomorrow',
          'Day Off',
          'Take a deep breath',
          'plane_take_off',
        );
      }
      return const NowState('home', 'Now', 'Home', 'Sweet Home', 'home');
    }
  }
  // Not a class day (or a class day with no classes in the grid): day off.
  return _dayOffState(items, now);
}

/// Today-later (maxDays 1) or within [maxDays] calendar days, for incoming.
String? _incomingLabel(List<Ct> items, DateTime now, {required int maxDays}) {
  final next = _nextItem(items, now);
  if (next != null && _calendarDays(now, next.at) <= maxDays) {
    return ctKindLabel(next.kind);
  }
  return null;
}

/// A day off for the next calendar day: not in the routine's days, or in
/// them with an empty grid (all cells null).
bool _tomorrowIsDayOff(Routine r, DateTime now) {
  final tomorrow = _dayNames[now.weekday % 7];
  if (!r.days.contains(tomorrow)) return true;
  return daySlots(r, tomorrow).isEmpty;
}

/// The class running now, with the next class as the card's third line.
NowState _classNow(NowSlot s, NowSlot? next) {
  final isLab = _isLab(s.cell.course);
  return NowState(
    isLab ? 'lab' : 'theory',
    'Now',
    s.cell.course,
    next == null ? '' : 'Next : ${next.cell.course} . ${next.cell.room}',
    isLab ? 'test_tube' : 'grad_cap',
    tail: s.cell.room,
  );
}

// --- day off --------------------------------------------------------------

NowState _dayOffState(List<Ct> items, DateTime now) {
  final next = _nextItem(items, now);
  if (next != null && _calendarDays(now, next.at) <= 2) {
    return NowState(
      'near',
      'Now',
      'Day Off',
      '${ctKindLabel(next.kind)} Near',
      'plane_take_off1',
    );
  }
  return const NowState('dayOff', 'Now', 'Day Off', 'Relaxing', 'plane');
}

// --- exam mode ------------------------------------------------------------

NowState _examMode(Routine r, List<Ct> items, DateTime now) {
  // Exams from today onward, in start order; passed times drop out at midnight.
  final upcoming = <(Exam, DateTime)>[];
  for (final e in r.exams) {
    final start = examStart(r, e, now);
    if (!_dateOnly(start).isBefore(_dateOnly(now))) upcoming.add((e, start));
  }
  if (upcoming.isEmpty) {
    // No exams entered, or the last one passed: class-mode behaviour until
    // the user switches the mode.
    return _classMode(r, items, now);
  }
  upcoming.sort((a, b) => a.$2.compareTo(b.$2));
  final (exam, start) = upcoming.first;
  final delta = start.difference(now);

  if (delta <= Duration.zero) {
    // Today's exam time has passed: the rest of the day follows the class
    // timeline (homecoming, home); the countdown resumes at midnight.
    return _classMode(r, items, now);
  }
  if (delta > const Duration(hours: 24)) {
    final days = _calendarDays(now, start);
    return NowState(
      'examDays',
      days == 1 ? '1 Day Left' : '$days Days Left',
      '${exam.course} exam',
      _examDate(exam),
      'clipboard48',
    );
  }
  if (_dateOnly(start) == _dateOnly(now)) {
    // Exam day: the card says go, no matter how many hours remain.
    return NowState('examToday', 'Today', '${exam.course} exam', _examDate(exam), 'clipboard_check');
  }
  // Under 24 hours and not the exam day yet: count in hours.
  return NowState(
    'examHours',
    '${(delta.inMinutes / 60).ceil()} Hours Left',
    '${exam.course} exam',
    _examDate(exam),
    'clipboard_arrow',
  );
}
