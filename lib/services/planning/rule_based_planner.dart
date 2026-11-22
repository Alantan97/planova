import '../../models/academic_task.dart';
import '../../models/study_preferences.dart';
import '../../models/study_session.dart';
import '../../models/weekly_availability.dart';
import 'free_study_slots.dart';

/// Limits for the rule-based planner. The defaults are the agreed baseline
/// (and match [StudyPreferences] defaults), so the report and a later GA
/// comparison can use the same numbers; students can change them on the
/// Profile tab.
class PlannerSettings {
  const PlannerSettings({
    this.horizonDays = 7,
    this.maxSessionMinutes = 60,
    this.minSessionMinutes = 30,
    this.breakMinutes = 15,
    this.dailyLimitMinutes = 240,
    this.perTaskDailyMinutes = 120,
    this.daysOff = const {},
  });

  /// The student's saved preferences, over the fixed 7-day horizon.
  PlannerSettings.fromPreferences(StudyPreferences p)
    : this(
        maxSessionMinutes: p.maxSessionMinutes,
        minSessionMinutes: p.minSessionMinutes,
        breakMinutes: p.breakMinutes,
        dailyLimitMinutes: p.dailyLimitMinutes,
        perTaskDailyMinutes: p.perTaskDailyMinutes,
        daysOff: p.daysOff,
      );

  final int horizonDays;
  final int maxSessionMinutes;
  final int minSessionMinutes;
  final int breakMinutes;
  final int dailyLimitMinutes;
  final int perTaskDailyMinutes;

  /// Weekdays (1 = Monday … 7 = Sunday) on which nothing is planned.
  final Set<int> daysOff;
}

enum UnplacedReason {
  /// Due within the plan period, but the free time before it ran out.
  notEnoughTimeBeforeDue,

  /// Due after the plan period; the rest is planned in a later week.
  continuesLater,

  /// No due date yet, so it cannot be ordered or placed.
  needsDueDate,

  /// The due date has already passed.
  overdue,
}

class UnplacedWork {
  const UnplacedWork(this.task, this.minutes, this.reason);
  final AcademicTask task;

  /// Work left after this plan (for needsDueDate/overdue: all remaining work).
  final int minutes;
  final UnplacedReason reason;
}

/// The planner's output. Nothing is saved until the student accepts it.
class PlanProposal {
  const PlanProposal({
    required this.from,
    required this.to,
    required this.sessions,
    required this.unplaced,
    required this.hasAvailability,
  });

  /// Plan period: [from, to).
  final DateTime from;
  final DateTime to;
  final List<StudySession> sessions;
  final List<UnplacedWork> unplaced;
  final bool hasAvailability;

  int get scheduledMinutes =>
      sessions.fold(0, (total, session) => total + session.minutes);
  int get taskCount => sessions.map((s) => s.taskId).toSet().length;

  /// Evaluation measures for the report and later comparisons.
  int get minutesNotPlacedBeforeDue => unplaced
      .where((u) => u.reason == UnplacedReason.notEnoughTimeBeforeDue)
      .fold(0, (total, u) => total + u.minutes);
  Map<DateTime, int> get minutesPerDay {
    final result = <DateTime, int>{};
    for (final s in sessions) {
      final day = DateTime(s.startsAt.year, s.startsAt.month, s.startsAt.day);
      result[day] = (result[day] ?? 0) + s.minutes;
    }
    return result;
  }
}

/// Deterministic, explainable baseline planner (no AI, no randomness).
///
/// Rules, in order:
/// 1. Eligible: active tasks with a future due date and work remaining.
/// 2. Order: earliest due date, then higher grade weight, then more work
///    remaining, then task ID (so equal inputs always give the same plan).
/// 3. Free time: study windows minus commitments ([freeStudySlots]), for the
///    next [PlannerSettings.horizonDays] days starting now.
/// 4. Fill each free slot in time order with the first task in priority order
///    that may still be studied: the session ends by its due date, it stays
///    under the daily and per-task-per-day limits, and it lasts at least the
///    minimum length (or the whole remainder if less is left). Sessions are at
///    most the maximum length, with a break between sessions in one slot.
/// 5. Work that does not fit is reported with a reason, never placed late.
PlanProposal planWeek({
  required List<AcademicTask> tasks,
  required WeeklyAvailability availability,
  required DateTime now,
  PlannerSettings settings = const PlannerSettings(),
}) {
  final start = _roundUpToFive(now);
  final firstDay = DateTime(now.year, now.month, now.day);
  final end = DateTime(
    firstDay.year,
    firstDay.month,
    firstDay.day + settings.horizonDays,
  );

  final unplaced = <UnplacedWork>[];
  final eligible = <AcademicTask>[];
  for (final task in tasks) {
    if (task.isCompleted) continue;
    final remaining = task.estimatedMinutes - task.completedMinutes;
    if (remaining <= 0) continue;
    final deadline = task.deadline;
    if (deadline == null) {
      unplaced.add(UnplacedWork(task, remaining, UnplacedReason.needsDueDate));
    } else if (!deadline.isAfter(now)) {
      unplaced.add(UnplacedWork(task, remaining, UnplacedReason.overdue));
    } else {
      eligible.add(task);
    }
  }
  eligible.sort(_priority);
  final remaining = {
    for (final t in eligible) t.id: t.estimatedMinutes - t.completedMinutes,
  };

  final slotsByWeekday = <int, List<FreeSlot>>{};
  for (final slot in freeStudySlots(availability)) {
    slotsByWeekday.putIfAbsent(slot.weekday, () => []).add(slot);
  }

  final sessions = <StudySession>[];
  for (var d = 0; d < settings.horizonDays; d++) {
    final day = DateTime(firstDay.year, firstDay.month, firstDay.day + d);
    if (settings.daysOff.contains(day.weekday)) continue;
    var dayUsed = 0;
    final taskToday = <String, int>{};
    for (final slot in slotsByWeekday[day.weekday] ?? const <FreeSlot>[]) {
      var cursor = day.add(Duration(minutes: slot.startMinute));
      final slotEnd = day.add(Duration(minutes: slot.endMinute));
      if (cursor.isBefore(start)) cursor = start;
      while (cursor.isBefore(slotEnd)) {
        final room = slotEnd.difference(cursor).inMinutes;
        final dayRoom = settings.dailyLimitMinutes - dayUsed;
        AcademicTask? chosen;
        var length = 0;
        for (final task in eligible) {
          final left = remaining[task.id]!;
          if (left <= 0) continue;
          final untilDue = task.deadline!.difference(cursor).inMinutes;
          final candidate = [
            settings.maxSessionMinutes,
            left,
            room,
            dayRoom,
            settings.perTaskDailyMinutes - (taskToday[task.id] ?? 0),
            untilDue,
          ].reduce((a, b) => a < b ? a : b);
          final needed = left < settings.minSessionMinutes
              ? left
              : settings.minSessionMinutes;
          if (candidate >= needed && candidate > 0) {
            chosen = task;
            length = candidate;
            break;
          }
        }
        if (chosen == null) break;
        sessions.add(
          StudySession(
            id: 'plan-${_stamp(cursor)}-${chosen.id}',
            taskId: chosen.id,
            title: chosen.title,
            subject: chosen.subject,
            startsAt: cursor,
            minutes: length,
          ),
        );
        remaining[chosen.id] = remaining[chosen.id]! - length;
        taskToday[chosen.id] = (taskToday[chosen.id] ?? 0) + length;
        dayUsed += length;
        cursor = cursor.add(Duration(minutes: length + settings.breakMinutes));
      }
    }
  }

  for (final task in eligible) {
    final left = remaining[task.id]!;
    if (left <= 0) continue;
    unplaced.add(
      UnplacedWork(
        task,
        left,
        task.deadline!.isBefore(end)
            ? UnplacedReason.notEnoughTimeBeforeDue
            : UnplacedReason.continuesLater,
      ),
    );
  }
  unplaced.sort((a, b) {
    final reason = a.reason.index.compareTo(b.reason.index);
    return reason != 0 ? reason : _priority(a.task, b.task);
  });

  return PlanProposal(
    from: start,
    to: end,
    sessions: sessions,
    unplaced: unplaced,
    hasAvailability: availability.windows.isNotEmpty,
  );
}

int _priority(AcademicTask a, AcademicTask b) {
  final due = AcademicTask.byDeadline(a, b);
  if (due != 0) return due;
  final weight = (b.assessmentWeightPercent ?? -1).compareTo(
    a.assessmentWeightPercent ?? -1,
  );
  if (weight != 0) return weight;
  final work = (b.estimatedMinutes - b.completedMinutes).compareTo(
    a.estimatedMinutes - a.completedMinutes,
  );
  return work != 0 ? work : a.id.compareTo(b.id);
}

/// Sessions start on 5-minute marks, never in the past.
DateTime _roundUpToFive(DateTime t) {
  final base = DateTime(t.year, t.month, t.day, t.hour, t.minute);
  final extra = (5 - base.minute % 5) % 5;
  final rounded = base.add(Duration(minutes: extra));
  return rounded.isBefore(t)
      ? rounded.add(const Duration(minutes: 5))
      : rounded;
}

String _stamp(DateTime t) =>
    '${t.year}${_two(t.month)}${_two(t.day)}${_two(t.hour)}${_two(t.minute)}';

// Shared with the balanced (GA) planner so both order tasks, start the plan
// and name sessions in exactly the same way.

/// Planning order: earliest due date, then higher grade weight, then more
/// work remaining, then task ID.
int comparePlanningPriority(AcademicTask a, AcademicTask b) => _priority(a, b);

/// The first moment a plan made at [now] may use (next 5-minute mark).
DateTime planStartFor(DateTime now) => _roundUpToFive(now);

/// The ID of a proposed session for [taskId] starting at [start].
String planSessionId(DateTime start, String taskId) =>
    'plan-${_stamp(start)}-$taskId';
String _two(int v) => v.toString().padLeft(2, '0');
