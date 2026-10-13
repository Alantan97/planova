enum SessionStatus { planned, completed, missed }

/// Framework-independent sample session; fixed commitments have no task ID.
class StudySession {
  const StudySession({
    required this.id,
    required this.title,
    required this.subject,
    required this.startsAt,
    required this.minutes,
    this.taskId,
    this.commitment = false,
    this.status = SessionStatus.planned,
  }) : assert(minutes > 0);

  final String id;
  final String? taskId;
  final String title;
  final String subject;
  final DateTime startsAt;
  final int minutes;
  final bool commitment;
  final SessionStatus status;

  String get time =>
      '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}';
}
