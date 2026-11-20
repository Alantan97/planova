import '../../core/time/date_time_helpers.dart';
import '../../models/study_session.dart';
import '../repositories/study_repository.dart';
import '../repositories/task_repository.dart';
import 'demo_sessions.dart';

class MockStudyRepository implements StudyRepository {
  MockStudyRepository({required this.tasks, bool includeSamples = true})
    : _sessions = List.unmodifiable(
        includeSamples ? demoSessions() : <StudySession>[],
      );
  final TaskRepository tasks;
  final List<StudySession> _sessions;

  @override
  int get weeklyGoalMinutes => 360;

  @override
  bool get showsSampleSessions => _sessions.isNotEmpty;

  @override
  List<StudySession> sessionsOn(DateTime date) {
    final sessions =
        _sessions
            .where(
              (session) =>
                  session.startsAt.year == date.year &&
                  session.startsAt.month == date.month &&
                  session.startsAt.day == date.day &&
                  (session.commitment ||
                      session.status != SessionStatus.planned ||
                      (tasks.taskById(session.taskId ?? '') != null &&
                          !tasks.taskById(session.taskId ?? '')!.isCompleted)),
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
