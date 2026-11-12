/// The kinds a scheduled item can be. Stored as plain strings in JSON so old
/// documents (which have no kind at all) read as a CT.
const ctKinds = {'ct', 'assignment', 'labReport', 'presentation'};

/// Human label for a kind, used on cards and the widget.
String ctKindLabel(String kind) => switch (kind) {
      'assignment' => 'Assignment',
      'labReport' => 'Lab Report',
      'presentation' => 'Presentation',
      _ => 'CT',
    };

class Ct {
  /// Firestore doc id. Empty for a CT that has not been saved yet.
  final String id;
  final String course;
  final DateTime at;
  final String? room, note;

  /// One of [ctKinds]; what this scheduled item actually is.
  final String kind;

  /// Minutes before [at] to send a reminder.
  final List<int> remindBefore;

  const Ct({
    required this.id,
    required this.course,
    required this.at,
    this.room,
    this.note,
    this.kind = 'ct',
    required this.remindBefore,
  });

  // Stored as epoch milliseconds so the moment stays the same in any time zone.
  Map<String, dynamic> toJson() => {
        'course': course,
        'at': at.millisecondsSinceEpoch,
        if (room != null) 'room': room,
        if (note != null) 'note': note,
        'kind': kind,
        'remindBefore': remindBefore,
      };

  /// Returns null for a malformed doc, so it can't be mistaken for an expired CT.
  static Ct? tryFromJson(String id, Map<String, dynamic> json) {
    final course = json['course'];
    final at = json['at'];
    final room = json['room'];
    final note = json['note'];
    final kind = json['kind'];
    final remindBefore = json['remindBefore'] ?? const [];
    if (course is! String || course.isEmpty || at is! num) return null;
    if (room != null && room is! String) return null;
    if (note != null && note is! String) return null;
    if (kind != null && !ctKinds.contains(kind)) return null;
    if (remindBefore is! List || remindBefore.any((m) => m is! num)) return null;
    return Ct(
      id: id,
      course: course,
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      room: room as String?,
      note: note as String?,
      kind: kind is String ? kind : 'ct',
      remindBefore: [for (final m in remindBefore) (m as num).toInt()],
    );
  }
}
