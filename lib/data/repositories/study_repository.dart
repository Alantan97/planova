import '../../models/study_session.dart';

abstract interface class StudyRepository {
  List<StudySession> sessionsOn(DateTime date);
  int completedMinutesInWeek(DateTime date);
  int get weeklyGoalMinutes;

  /// True only when the sessions shown are illustrative samples (demo build).
  /// Real local mode has no sessions until the planner is implemented.
  bool get showsSampleSessions;
}
