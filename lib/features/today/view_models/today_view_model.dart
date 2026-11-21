import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../data/repositories/study_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_task.dart';
import '../../../models/study_session.dart';

class TodayViewModel {
  const TodayViewModel({
    required this.studyRepository,
    required this.taskRepository,
    required this.clock,
  });
  final StudyRepository studyRepository;
  final TaskRepository taskRepository;
  final AppClock clock;

  List<StudySession> get sessions => studyRepository.sessionsOn(clock.now());
  StudySession? get nextSession {
    for (final session in sessions) {
      if (!session.commitment &&
          session.status == SessionStatus.planned &&
          !session.startsAt.isBefore(clock.now())) {
        return session;
      }
    }
    return null;
  }

  AcademicTask? get upcomingTask {
    final tasks =
        taskRepository.tasks
            .where((task) => !task.isCompleted && task.hasDeadline)
            .toList()
          ..sort(AcademicTask.byDeadline);
    return tasks.firstOrNull;
  }

  String get dateLabel {
    final date = clock.now();
    return '${fullWeekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}'
        .toUpperCase();
  }

  String get workloadLabel {
    final study = sessions.where((session) => !session.commitment);
    final minutes = study.fold(0, (total, session) => total + session.minutes);
    return '${study.length} study ${study.length == 1 ? 'session' : 'sessions'} · ${formatDuration(minutes)} planned';
  }

  int get completedMinutes =>
      studyRepository.completedMinutesInWeek(clock.now());
  int get goalMinutes => studyRepository.weeklyGoalMinutes;
}
