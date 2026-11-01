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

  factory Ct.fromJson(String id, Map<String, dynamic> json) => Ct(
        id: id,
        course: '${json['course'] ?? ''}',
        at: DateTime.fromMillisecondsSinceEpoch(
          (json['at'] as num?)?.toInt() ?? 0,
        ),
        room: json['room'] as String?,
        note: json['note'] as String?,
        remindBefore: [
          for (final minutes in (json['remindBefore'] as List?) ?? const [])
            (minutes as num).toInt(),
        ],
      );
}
