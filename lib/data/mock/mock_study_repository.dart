import '../../core/time/demo_clock.dart';
import '../../models/study_session.dart';
import '../repositories/study_repository.dart';
import 'demo_sessions.dart';

class MockStudyRepository implements StudyRepository {
  MockStudyRepository() : _sessions = List.unmodifiable(demoSessions());
  final List<StudySession> _sessions;

  @override
  int get weeklyGoalMinutes => 360;

  @override
  List<StudySession> sessionsOn(DateTime date) {
    final sessions =
        _sessions
            .where(
              (session) =>
                  session.startsAt.year == date.year &&
                  session.startsAt.month == date.month &&
                  session.startsAt.day == date.day,
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return List.unmodifiable(sessions);
  }

  @override
  int completedMinutesInWeek(DateTime date) {
    final start = startOfWeek(date);
    final end = DateTime(start.year, start.month, start.day + 7);
    return _sessions
        .where(
          (session) =>
              !session.commitment &&
              session.status == SessionStatus.completed &&
              !session.startsAt.isBefore(start) &&
              session.startsAt.isBefore(end),
        )
        .fold(0, (total, session) => total + session.minutes);
  }
}
