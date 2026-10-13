import '../../models/study_session.dart';

abstract interface class StudyRepository {
  List<StudySession> sessionsOn(DateTime date);
  int completedMinutesInWeek(DateTime date);
  int get weeklyGoalMinutes;
}
