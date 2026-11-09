import 'dart:convert';

const validDays = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
const _validAccents = {
  'blue',
  'indigo',
  'teal',
  'green',
  'orange',
  'pink',
  'purple',
};

const _validThemeModes = {'system', 'light', 'dark'};

final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

class Period {
  final String start, end;

  const Period(this.start, this.end);

  int get startMinute => _minutes(start);
  int get endMinute => _minutes(end);

  static int _minutes(String time) =>
      int.parse(time.substring(0, 2)) * 60 + int.parse(time.substring(3));

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
}

class ClassCell {
  final String course, teacher, room;
  final bool tough;

  const ClassCell({
    required this.course,
    required this.teacher,
    required this.room,
    this.tough = false,
  });

  bool sameClass(ClassCell? other) =>
      other != null &&
      course == other.course &&
      teacher == other.teacher &&
      room == other.room;

  /// `COURSE · TEACHER · ROOM`, leaving out a blank teacher.
  String get label => [
        course,
        if (teacher.isNotEmpty) teacher,
        room,
      ].join(' · ');

  Map<String, dynamic> toJson() => {
        'course': course,
        'teacher': teacher,
        'room': room,
        if (tough) 'tough': true,
      };
}

class Routine {
  final String accent;

  /// "system", "light" or "dark"; see [_validThemeModes].
  final String themeMode;
  final List<String> days;
  final List<Period> periods;
  final Map<String, String> teachers;
  final Map<String, List<ClassCell?>> cells;

  const Routine({
    required this.accent,
    this.themeMode = 'system',
    required this.days,
    required this.periods,
    required this.teachers,
    required this.cells,
  });

  factory Routine.empty() => const Routine(
        accent: 'blue',
        days: [],
        periods: [],
        teachers: {},
        cells: {},
      );

  /// The day's cells, one per period. A day with no stored row is all empty.
  List<ClassCell?> row(String day) =>
      cells[day] ?? List<ClassCell?>.filled(periods.length, null);

  Routine copyWith({
    String? accent,
    String? themeMode,
    List<String>? days,
    List<Period>? periods,
    Map<String, String>? teachers,
    Map<String, List<ClassCell?>>? cells,
  }) =>
      Routine(
        accent: accent ?? this.accent,
        themeMode: themeMode ?? this.themeMode,
        days: days ?? this.days,
        periods: periods ?? this.periods,
        teachers: teachers ?? this.teachers,
        cells: cells ?? this.cells,
      );

  Routine withCell(String day, int period, ClassCell? cell) {
    final updated = List<ClassCell?>.of(row(day));
    updated[period] = cell;
    return copyWith(cells: {...cells, day: updated});
  }

  /// Replaces the periods, padding or truncating every row so cells stay aligned.
  Routine withPeriods(List<Period> newPeriods) {
    final resized = <String, List<ClassCell?>>{};
    cells.forEach((day, row) {
      resized[day] = List<ClassCell?>.generate(
        newPeriods.length,
        (i) => i < row.length ? row[i] : null,
      );
    });
    return copyWith(periods: newPeriods, cells: resized);
  }

  /// Drops one period and its cell in every row, keeping the other columns aligned.
  Routine withoutPeriod(int index) => copyWith(
        periods: [...periods]..removeAt(index),
        cells: cells.map(
          (day, row) => MapEntry(day, [...row]..removeAt(index)),
        ),
      );

  /// Replaces the class days. Rows of removed days are dropped, as [parse] rejects them.
  Routine withDays(List<String> newDays) => copyWith(
        days: newDays,
        cells: {
          for (final entry in cells.entries)
            if (newDays.contains(entry.key)) entry.key: entry.value,
        },
      );

  Map<String, dynamic> toJson() => {
        'accent': accent,
        'themeMode': themeMode,
        'days': days,
        'periods': periods.map((p) => p.toJson()).toList(),
        'teachers': teachers,
        'cells': cells.map(
          (day, row) => MapEntry(day, row.map((c) => c?.toJson()).toList()),
        ),
      };

  /// Like [parse], for raw text from an imported file.
  static (Routine?, List<String>) parseText(String text) {
    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic>) return parse(json);
      return (null, ['The file must be one JSON object.']);
    } on FormatException catch (e) {
      return (null, ['This is not valid JSON: ${e.message}']);
    }
  }

  /// Returns the routine, or null with every problem found. Never throws on bad input.
  static (Routine?, List<String>) parse(Map<String, dynamic> json) {
    final errors = <String>[];

    final days = <String>[];
    final rawDays = json['days'];
    if (rawDays is! List) {
      errors.add('"days" must be a list.');
    } else {
      for (final day in rawDays) {
        if (day is! String || !validDays.contains(day)) {
          errors.add('Unknown day "$day". Use: ${validDays.join(', ')}.');
        } else if (days.contains(day)) {
          errors.add('Day "$day" is listed twice.');
        } else {
          days.add(day);
        }
      }
    }

    final periods = <Period>[];
    final rawPeriods = json['periods'];
    if (rawPeriods is! List) {
      errors.add('"periods" must be a list.');
    } else {
      for (var i = 0; i < rawPeriods.length; i++) {
        final label = 'Period ${i + 1}';
        final raw = rawPeriods[i];
        final start = raw is Map ? raw['start'] : null;
        final end = raw is Map ? raw['end'] : null;
        if (start is! String ||
            end is! String ||
            !_timePattern.hasMatch(start) ||
            !_timePattern.hasMatch(end)) {
          errors.add('$label needs "start" and "end" as 24-hour HH:mm.');
          continue;
        }
        final period = Period(start, end);
        if (period.startMinute >= period.endMinute) {
          errors.add('$label starts at or after its end.');
        }
        if (periods.isNotEmpty && period.startMinute < periods.last.endMinute) {
          errors.add('$label overlaps or comes before the previous period.');
        }
        periods.add(period);
      }
    }

    final teachers = <String, String>{};
    final rawTeachers = json['teachers'];
    if (rawTeachers is Map) {
      rawTeachers.forEach((k, v) => teachers['$k'] = '$v');
    } else if (rawTeachers != null) {
      errors.add('"teachers" must be a map of initials to names.');
    }

    final cells = <String, List<ClassCell?>>{};
    final rawCells = json['cells'];
    if (rawCells is Map) {
      rawCells.forEach((day, rawRow) {
        if (!days.contains(day)) {
          errors.add('"cells" has a row for "$day", which is not in "days".');
          return;
        }
        if (rawRow is! List || rawRow.length != periods.length) {
          errors.add('$day needs exactly ${periods.length} cells.');
          return;
        }
        final row = <ClassCell?>[];
        for (var i = 0; i < rawRow.length; i++) {
          final raw = rawRow[i];
          if (raw == null) {
            row.add(null);
            continue;
          }
          final course = raw is Map ? raw['course'] : null;
          final room = raw is Map ? raw['room'] : null;
          if (course is! String ||
              room is! String ||
              course.trim().isEmpty ||
              room.trim().isEmpty) {
            errors.add('$day period ${i + 1} needs a course and a room.');
            continue;
          }
          row.add(ClassCell(
            course: course,
            teacher: '${raw['teacher'] ?? ''}',
            room: room,
            tough: raw['tough'] == true,
          ));
        }
        cells[day as String] = row;
      });
    } else if (rawCells != null) {
      errors.add('"cells" must be a map of day to cells.');
    }

    if (errors.isNotEmpty) return (null, errors);

    final accent = json['accent'];
    final themeMode = json['themeMode'];
    return (
      Routine(
        accent: _validAccents.contains(accent) ? accent as String : 'blue',
        themeMode: _validThemeModes.contains(themeMode)
            ? themeMode as String
            : 'system',
        days: days,
        periods: periods,
        teachers: teachers,
        cells: cells,
      ),
      <String>[],
    );
  }
}
