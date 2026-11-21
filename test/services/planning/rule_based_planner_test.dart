import 'package:flutter_test/flutter_test.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/weekly_availability.dart';
import 'package:planova/services/planning/rule_based_planner.dart';

/// Wednesday 14 October 2026, 13:00 (the app's preview clock).
final now = DateTime(2026, 10, 14, 13);
int at(int h, [int m = 0]) => h * 60 + m;

AcademicTask task(
  String id,
  int minutes, {
  DateTime? due,
  double? weight,
  bool done = false,
}) => AcademicTask(
  id: id,
  title: 'Task $id',
  subject: 'DES3113',
  description: '',
  deadline: due,
  estimatedMinutes: minutes,
  assessmentWeightPercent: weight,
  status: done ? TaskStatus.completed : TaskStatus.active,
);

WeeklyAvailability week(
  List<int> days,
  int start,
  int end, {
  List<RecurringCommitment> commitments = const [],
}) => WeeklyAvailability(
  windows: [
    StudyWindow(
      id: 'w',
      range: WeeklyTimeRange(
        weekdays: days,
        startMinute: start,
        endMinute: end,
      ),
    ),
  ],
  commitments: commitments,
);

String slot(PlanProposal p, int i) {
  final s = p.sessions[i];
  return '${s.taskId} ${s.startsAt.day} ${s.time} ${s.minutes}';
}

void main() {
  test('Earliest due date first, sessions up to 60 min with 15 min breaks', () {
    final p = planWeek(
      tasks: [
        task('A', 120, due: DateTime(2026, 10, 16, 23, 59), weight: 10),
        task('B', 60, due: DateTime(2026, 10, 15, 23, 59), weight: 50),
      ],
      availability: week([1, 2, 3, 4, 5], at(20), at(22)),
      now: now,
    );
    expect(
      [for (var i = 0; i < p.sessions.length; i++) slot(p, i)],
      ['B 14 20:00 60', 'A 14 21:15 45', 'A 15 20:00 60', 'A 15 21:15 15'],
    );
    expect(p.scheduledMinutes, 180);
    expect(p.unplaced, isEmpty);
    expect(p.taskCount, 2);
  });

  test('Ties on due date go to the higher grade weight', () {
    final due = DateTime(2026, 10, 20, 23, 59);
    final p = planWeek(
      tasks: [
        task('low', 60, due: due, weight: 10),
        task('high', 60, due: due, weight: 40),
      ],
      availability: week([3], at(20), at(21)),
      now: now,
    );
    expect(p.sessions.single.taskId, 'high');
    expect(p.unplaced.single.task.id, 'low');
    expect(p.unplaced.single.reason, UnplacedReason.notEnoughTimeBeforeDue);
  });

  test('Sessions never run past the due date; the rest is reported', () {
    final p = planWeek(
      tasks: [task('A', 120, due: DateTime(2026, 10, 14, 20, 30))],
      availability: week([3], at(20), at(22)),
      now: now,
    );
    expect(slot(p, 0), 'A 14 20:00 30');
    expect(p.sessions.length, 1);
    expect(p.unplaced.single.minutes, 90);
    expect(p.unplaced.single.reason, UnplacedReason.notEnoughTimeBeforeDue);
    expect(p.minutesNotPlacedBeforeDue, 90);
  });

  test('Commitments are never overlapped', () {
    final p = planWeek(
      tasks: [task('A', 600, due: DateTime(2026, 10, 30))],
      availability: week(
        [3],
        at(18),
        at(22),
        commitments: [
          RecurringCommitment(
            id: 'c',
            title: 'Futsal',
            category: CommitmentCategory.club,
            range: WeeklyTimeRange(
              weekdays: [3],
              startMinute: at(19),
              endMinute: at(21),
            ),
          ),
        ],
      ),
      now: now,
    );
    final busyStart = DateTime(2026, 10, 14, 19);
    final busyEnd = DateTime(2026, 10, 14, 21);
    for (final s in p.sessions) {
      final end = s.startsAt.add(Duration(minutes: s.minutes));
      expect(end.isAfter(busyStart) && s.startsAt.isBefore(busyEnd), isFalse);
    }
    expect(
      [for (var i = 0; i < p.sessions.length; i++) slot(p, i)],
      ['A 14 18:00 60', 'A 14 21:00 60'],
    );
  });

  test('Daily and per-task limits spread long work across days', () {
    final p = planWeek(
      tasks: [
        task('A', 3000, due: DateTime(2026, 11, 30)),
        task('B', 3000, due: DateTime(2026, 12, 1)),
        task('C', 3000, due: DateTime(2026, 12, 2)),
      ],
      availability: week([1, 2, 3, 4, 5, 6, 7], at(8), at(22)),
      now: now,
    );
    for (final minutes in p.minutesPerDay.values) {
      expect(minutes, lessThanOrEqualTo(240));
    }
    final perTaskDay = <String, int>{};
    for (final s in p.sessions) {
      final key = '${s.taskId}-${s.startsAt.day}';
      perTaskDay[key] = (perTaskDay[key] ?? 0) + s.minutes;
    }
    expect(perTaskDay.values.every((m) => m <= 120), isTrue);
    // A and B share each day; C is reported as continuing later.
    expect(p.sessions.map((s) => s.taskId).toSet(), {'A', 'B'});
    expect(p.unplaced.map((u) => u.reason).toSet(), {
      UnplacedReason.continuesLater,
    });
  });

  test('Planning starts now, not earlier in the day', () {
    final p = planWeek(
      tasks: [task('A', 60, due: DateTime(2026, 10, 20))],
      availability: week([3], at(8), at(18)),
      now: DateTime(2026, 10, 14, 13, 2),
    );
    expect(slot(p, 0), 'A 14 13:05 60');
  });

  test('Gaps shorter than 30 minutes are left free', () {
    final p = planWeek(
      tasks: [task('A', 60, due: DateTime(2026, 10, 20))],
      availability: week([3, 4], at(20), at(20, 20)),
      now: now,
    );
    expect(p.sessions, isEmpty);
    expect(p.unplaced.single.reason, UnplacedReason.notEnoughTimeBeforeDue);
  });

  test('Undated, overdue and completed tasks are never planned', () {
    final p = planWeek(
      tasks: [
        task('undated', 60),
        task('overdue', 60, due: DateTime(2026, 10, 13)),
        task('done', 60, due: DateTime(2026, 10, 20), done: true),
      ],
      availability: week([1, 2, 3, 4, 5], at(20), at(22)),
      now: now,
    );
    expect(p.sessions, isEmpty);
    expect(
      {for (final u in p.unplaced) u.task.id: u.reason},
      {
        'undated': UnplacedReason.needsDueDate,
        'overdue': UnplacedReason.overdue,
      },
    );
  });

  test('No availability gives no sessions and says so', () {
    final p = planWeek(
      tasks: [task('A', 60, due: DateTime(2026, 10, 20))],
      availability: WeeklyAvailability(),
      now: now,
    );
    expect(p.hasAvailability, isFalse);
    expect(p.sessions, isEmpty);
  });

  test('Same inputs always give the same plan', () {
    List<String> run() {
      final p = planWeek(
        tasks: [
          task('A', 200, due: DateTime(2026, 10, 18)),
          task('B', 200, due: DateTime(2026, 10, 18)),
        ],
        availability: week([1, 2, 3, 4, 5, 6, 7], at(9), at(12)),
        now: now,
      );
      return [for (final s in p.sessions) '${s.id}/${s.minutes}'];
    }

    expect(run(), run());
    expect(run(), isNotEmpty);
  });
}
