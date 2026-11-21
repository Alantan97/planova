import 'package:flutter/foundation.dart';

import '../../models/study_session.dart';
import 'availability_repository.dart';
import 'study_repository.dart';
import 'task_repository.dart';

/// Real (non-sample) study sessions: the accepted rule-based plan.
///
/// Implements [StudyRepository], so Today, Plan and Progress read it exactly
/// like the old sample repository. Each day also shows the student's
/// recurring commitments as fixed blocks.
abstract class StudyPlanRepository extends ChangeNotifier
    implements StudyRepository {
  StudyPlanRepository({required this.tasks, required this.availability}) {
    tasks.addListener(notifyListeners);
    availability.addListener(notifyListeners);
  }
  final TaskRepository tasks;
  final AvailabilityRepository availability;

  /// Every saved session, including ones whose task is gone (kept as history).
  List<StudySession> get savedSessions;

  /// Replaces planned sessions starting in [from, to) with [sessions].
  /// Sessions outside that period, or no longer "planned", are kept.
  Future<void> acceptPlan(
    List<StudySession> sessions, {
    required DateTime from,
    required DateTime to,
  });

  bool get hasPlan => savedSessions.isNotEmpty;

  @override
  bool get showsSampleSessions => false;

  @override
  int get weeklyGoalMinutes => 0;

  @override
  List<StudySession> sessionsOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final study = savedSessions.where((s) {
      if (!_sameDay(s.startsAt, day)) return false;
      if (s.status != SessionStatus.planned) return true;
      // A planned session disappears once its task is completed or deleted.
      final task = tasks.taskById(s.taskId ?? '');
      return task != null && !task.isCompleted;
    });
    final fixed = availability.availability.commitments
        .where((c) => c.range.weekdays.contains(day.weekday))
        .map(
          (c) => StudySession(
            id: 'commitment-${c.id}-${day.toIso8601String()}',
            title: c.title,
            subject: c.category.label,
            startsAt: day.add(Duration(minutes: c.range.startMinute)),
            minutes: c.range.minutesPerOccurrence,
            commitment: true,
          ),
        );
    return List.unmodifiable(
      [...study, ...fixed]..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
    );
  }

  @override
  int completedMinutesInWeek(DateTime date) {
    final start = DateTime(date.year, date.month, date.day - date.weekday + 1);
    final end = start.add(const Duration(days: 7));
    return savedSessions
        .where(
          (s) =>
              s.status == SessionStatus.completed &&
              !s.startsAt.isBefore(start) &&
              s.startsAt.isBefore(end),
        )
        .fold(0, (total, s) => total + s.minutes);
  }

  /// Shared replace rule for local and in-memory storage.
  static List<StudySession> replacing(
    List<StudySession> current,
    List<StudySession> incoming,
    DateTime from,
    DateTime to,
  ) => [
    ...current.where(
      (s) =>
          s.status != SessionStatus.planned ||
          s.startsAt.isBefore(from) ||
          !s.startsAt.isBefore(to),
    ),
    ...incoming,
  ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  @override
  void dispose() {
    tasks.removeListener(notifyListeners);
    availability.removeListener(notifyListeners);
    super.dispose();
  }

  Future<void> close() async => dispose();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Non-persistent plan storage for tests and previews.
class MemoryStudyPlanRepository extends StudyPlanRepository {
  MemoryStudyPlanRepository({
    required super.tasks,
    required super.availability,
  });
  List<StudySession> _sessions = const [];

  @override
  List<StudySession> get savedSessions => _sessions;

  @override
  Future<void> acceptPlan(
    List<StudySession> sessions, {
    required DateTime from,
    required DateTime to,
  }) async {
    _sessions = List.unmodifiable(
      StudyPlanRepository.replacing(_sessions, sessions, from, to),
    );
    notifyListeners();
  }
}
