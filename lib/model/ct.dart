class Ct {
  /// Firestore doc id. Empty for a CT that has not been saved yet.
  final String id;
  final String course;
  final DateTime at;
  final String? room, note;

  /// Minutes before [at] to send a reminder.
  final List<int> remindBefore;

  const Ct({
    required this.id,
    required this.course,
    required this.at,
    this.room,
    this.note,
    required this.remindBefore,
  });

  // Stored as epoch milliseconds so the moment stays the same in any time zone.
  Map<String, dynamic> toJson() => {
        'course': course,
        'at': at.millisecondsSinceEpoch,
        if (room != null) 'room': room,
        if (note != null) 'note': note,
        'remindBefore': remindBefore,
      };

  /// Returns null for a malformed doc, so it can't be mistaken for an expired CT.
  static Ct? tryFromJson(String id, Map<String, dynamic> json) {
    final course = json['course'];
    final at = json['at'];
    final room = json['room'];
    final note = json['note'];
    final remindBefore = json['remindBefore'] ?? const [];
    if (course is! String || course.isEmpty || at is! num) return null;
    if (room != null && room is! String) return null;
    if (note != null && note is! String) return null;
    if (remindBefore is! List || remindBefore.any((m) => m is! num)) return null;
    return Ct(
      id: id,
      course: course,
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      room: room as String?,
      note: note as String?,
      remindBefore: [for (final m in remindBefore) (m as num).toInt()],
    );
  }
}
