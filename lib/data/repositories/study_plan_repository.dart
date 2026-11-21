import 'package:flutter/foundation.dart';

import '../../models/study_session.dart';
import 'availability_repository.dart';
import 'study_repository.dart';
import 'task_repository.dart';

/// Real (non-sample) study sessions: the accepted rule-based plan and what
/// the student recorded for each session.
///
/// Implements [StudyRepository], so Today, Plan and Progress read it exactly
/// like the old sample repository. Each day also shows the student's
/// recurring commitments as fixed blocks.
///
/// All rules live here; subclasses only decide where the state is stored.
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

  /// True after a session was missed or cut short, until the student accepts
  /// a new plan. Today then suggests re-planning.
  bool get needsReplan;

  /// Saves the whole state. Must only update the in-memory copy (and notify)
  /// after storage accepted it.
  @protected
  Future<void> writeState(
    List<StudySession> sessions, {
    required bool needsReplan,
  });

  /// Replaces planned sessions starting in [from, to) with [sessions].
  /// Recorded sessions and sessions outside that period are kept.
  Future<void> acceptPlan(
    List<StudySession> sessions, {
    required DateTime from,
    required DateTime to,
  }) => writeState(
    replacing(savedSessions, sessions, from, to),
    needsReplan: false,
  );

  /// Records what happened in a session and updates the task's progress.
  ///
  /// The task gains the difference between the new and any earlier recorded
  /// minutes, so correcting a mistake never double-counts. If more was studied
  /// than estimated, the estimate grows to match instead of being rejected.
  /// Missed or partly done sessions mark the plan as needing an update.
  Future<void> recordOutcome(
    String sessionId,
    SessionStatus status, {
    int? recordedMinutes,
  }) async {
    final index = savedSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) throw StateError('This session no longer exists.');
    final before = savedSessions[index];
    final after = before.withOutcome(
      status,
      recordedMinutes: switch (status) {
        SessionStatus.completed => recordedMinutes ?? before.minutes,
        SessionStatus.partial => recordedMinutes,
        _ => null,
      },
    );
    if (status == SessionStatus.partial &&
        (after.recordedMinutes == null || after.recordedMinutes! <= 0)) {
      throw const FormatException('Enter the minutes you studied.');
    }
    final delta = after.studiedMinutes - before.studiedMinutes;
    final task = tasks.taskById(before.taskId ?? '');
    if (task != null && delta != 0) {
      final completed = (task.completedMinutes + delta).clamp(0, 1 << 30);
      await tasks.update(
        task.copyWith(
          completedMinutes: completed,
          estimatedMinutes: completed > task.estimatedMinutes
              ? completed
              : task.estimatedMinutes,
        ),
      );
    }
    final next = [...savedSessions]..[index] = after;
    try {
      await writeState(
        next,
        needsReplan:
            needsReplan ||
            status == SessionStatus.missed ||
            status == SessionStatus.partial,
      );
    } catch (_) {
      // Keep task progress and sessions consistent if saving the session fails.
      if (task != null && delta != 0) await tasks.update(task);
      rethrow;
    }
  }

  bool get hasPlan => savedSessions.isNotEmpty;

  /// Planned sessions that have ended but were never recorded, oldest first.
  List<StudySession> unrecordedBefore(DateTime now) => savedSessions.where((s) {
    if (s.isRecorded || s.endsAt.isAfter(now)) return false;
    final task = tasks.taskById(s.taskId ?? '');
    return task != null && !task.isCompleted;
  }).toList();

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

  Iterable<StudySession> _inWeek(DateTime date) {
    final start = DateTime(date.year, date.month, date.day - date.weekday + 1);
    final end = DateTime(start.year, start.month, start.day + 7);
    return savedSessions.where(
      (s) => !s.startsAt.isBefore(start) && s.startsAt.isBefore(end),
    );
  }

  /// Minutes actually studied this week (done and partly done sessions).
  @override
  int completedMinutesInWeek(DateTime date) =>
      _inWeek(date).fold(0, (total, s) => total + s.studiedMinutes);

  /// Minutes planned this week, recorded or not: the week's study goal.
  int plannedMinutesInWeek(DateTime date) =>
      _inWeek(date).fold(0, (total, s) => total + s.minutes);

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
  bool _needsReplan = false;

  @override
  List<StudySession> get savedSessions => _sessions;
  @override
  bool get needsReplan => _needsReplan;

  @override
  Future<void> writeState(
    List<StudySession> sessions, {
    required bool needsReplan,
  }) async {
    _sessions = List.unmodifiable(sessions);
    _needsReplan = needsReplan;
    notifyListeners();
  }
}
