enum SessionStatus { planned, completed, partial, missed }

/// A study session or a fixed commitment (commitments have no task ID).
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
    this.recordedMinutes,
  }) : assert(minutes > 0);

  final String id;
  final String? taskId;
  final String title;
  final String subject;
  final DateTime startsAt;

  /// Planned length.
  final int minutes;
  final bool commitment;
  final SessionStatus status;

  /// Minutes the student says they actually studied (done or partly done).
  /// Null means not recorded; completed sessions then count as [minutes].
  final int? recordedMinutes;

  DateTime get endsAt => startsAt.add(Duration(minutes: minutes));
  bool get isRecorded => status != SessionStatus.planned;

  /// Study time this session contributes to its task and to Progress.
  int get studiedMinutes => switch (status) {
    SessionStatus.completed => recordedMinutes ?? minutes,
    SessionStatus.partial => recordedMinutes ?? 0,
    _ => 0,
  };

  StudySession withOutcome(SessionStatus status, {int? recordedMinutes}) =>
      StudySession(
        id: id,
        taskId: taskId,
        title: title,
        subject: subject,
        startsAt: startsAt,
        minutes: minutes,
        commitment: commitment,
        status: status,
        recordedMinutes: recordedMinutes,
      );

  String get time =>
      '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}';
}
