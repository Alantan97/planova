import 'dart:convert';
import 'dart:io';

import 'package:planova/models/academic_task.dart';
import 'package:planova/models/weekly_availability.dart';
import 'package:planova/services/planning/rule_based_planner.dart';

/// One shared test week from ai/scenarios/ (also used by the Python
/// evaluation), turned into the planner's real inputs.
class ScenarioWeek {
  ScenarioWeek(this.raw)
    : id = raw['id'] as String,
      tasks = [
        for (final t in (raw['tasks'] as List).cast<Map<String, dynamic>>())
          AcademicTask(
            id: t['id'] as String,
            title: t['title'] as String,
            subject: 'Scenario',
            description: '',
            deadline: t['due'] == null
                ? null
                : DateTime.parse(t['due'] as String),
            estimatedMinutes: t['estimatedMinutes'] as int,
            completedMinutes: t['completedMinutes'] as int? ?? 0,
            assessmentWeightPercent: (t['weightPercent'] as num?)?.toDouble(),
            status: t['completed'] == true
                ? TaskStatus.completed
                : TaskStatus.active,
          ),
      ],
      availability = WeeklyAvailability(
        windows: [
          for (final (i, w)
              in (raw['windows'] as List).cast<Map<String, dynamic>>().indexed)
            StudyWindow(id: 'w$i', range: _range(w)),
        ],
        commitments: [
          for (final (i, c)
              in (raw['commitments'] as List)
                  .cast<Map<String, dynamic>>()
                  .indexed)
            RecurringCommitment(
              id: 'c$i',
              title: c['title'] as String? ?? 'Commitment',
              category: CommitmentCategory.other,
              range: _range(c),
            ),
        ],
      ),
      now = DateTime.parse(raw['now'] as String),
      settings = _settings(raw['settings'] as Map<String, dynamic>);

  final Map<String, dynamic> raw;
  final String id;
  final List<AcademicTask> tasks;
  final WeeklyAvailability availability;
  final DateTime now;
  final PlannerSettings settings;

  static List<ScenarioWeek> all() =>
      (Directory('ai/scenarios')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
          .map(
            (f) => ScenarioWeek(
              jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
            ),
          )
          .toList();

  static PlannerSettings _settings(Map<String, dynamic> s) => PlannerSettings(
    horizonDays: s['horizonDays'] as int,
    maxSessionMinutes: s['maxSessionMinutes'] as int,
    minSessionMinutes: s['minSessionMinutes'] as int,
    breakMinutes: s['breakMinutes'] as int,
    dailyLimitMinutes: s['dailyLimitMinutes'] as int,
    perTaskDailyMinutes: s['perTaskDailyMinutes'] as int,
    daysOff: (s['daysOff'] as List).cast<int>().toSet(),
  );

  static WeeklyTimeRange _range(Map<String, dynamic> raw) => WeeklyTimeRange(
    weekdays: (raw['weekdays'] as List).cast<int>(),
    startMinute: _clock(raw['start'] as String),
    endMinute: _clock(raw['end'] as String),
  );

  static int _clock(String text) {
    final parts = text.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }
}

/// A plan in the saved-plan format shared with the Python evaluation.
Map<String, Object?> encodePlan(PlanProposal p) => {
  'from': formatPlanTime(p.from),
  'to': formatPlanTime(p.to),
  'sessions': [
    for (final s in p.sessions)
      {
        'taskId': s.taskId,
        'start': formatPlanTime(s.startsAt),
        'minutes': s.minutes,
      },
  ],
  'unplaced': [
    for (final u in p.unplaced)
      {'taskId': u.task.id, 'minutes': u.minutes, 'reason': u.reason.name},
  ],
};

String formatPlanTime(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}'
    'T${_two(t.hour)}:${_two(t.minute)}';
String _two(int v) => v.toString().padLeft(2, '0');
