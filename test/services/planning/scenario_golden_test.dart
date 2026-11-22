import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/weekly_availability.dart';
import 'package:planova/services/planning/rule_based_planner.dart';

/// Runs the app's planner on the shared test weeks in ai/scenarios/ and
/// compares each plan with ai/scenarios/expected/. The Python copy of the
/// planner (ai/planova_scheduling/baseline.py) is checked against the same
/// files, so the evaluation baseline is exactly the app's planner.
///
/// After an intended planner change, rewrite the expected plans with:
///   $env:PLANOVA_UPDATE_GOLDEN='1'; flutter test test/services/planning/scenario_golden_test.dart
void main() {
  final update = Platform.environment['PLANOVA_UPDATE_GOLDEN'] == '1';
  final files =
      Directory('ai/scenarios')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('Test weeks exist', () => expect(files, isNotEmpty));

  for (final file in files) {
    final scenario =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final id = scenario['id'] as String;
    test('Planner matches the saved plan: $id', () {
      final plan = _encode(_run(scenario));
      final expected = File('ai/scenarios/expected/$id.json');
      if (update) {
        expected.parent.createSync(recursive: true);
        expected.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(plan)}\n',
        );
      }
      expect(
        plan,
        jsonDecode(expected.readAsStringSync()),
        reason:
            'Run with PLANOVA_UPDATE_GOLDEN=1 only after an intended change.',
      );
    });
  }
}

DateTime _time(String text) => DateTime.parse(text);

String _format(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}'
    'T${_two(t.hour)}:${_two(t.minute)}';
String _two(int v) => v.toString().padLeft(2, '0');

int _clock(String text) {
  final parts = text.split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}

WeeklyTimeRange _range(Map<String, dynamic> raw) => WeeklyTimeRange(
  weekdays: (raw['weekdays'] as List).cast<int>(),
  startMinute: _clock(raw['start'] as String),
  endMinute: _clock(raw['end'] as String),
);

PlanProposal _run(Map<String, dynamic> scenario) {
  final s = scenario['settings'] as Map<String, dynamic>;
  final windows = (scenario['windows'] as List).cast<Map<String, dynamic>>();
  final commitments = (scenario['commitments'] as List)
      .cast<Map<String, dynamic>>();
  return planWeek(
    tasks: [
      for (final t in (scenario['tasks'] as List).cast<Map<String, dynamic>>())
        AcademicTask(
          id: t['id'] as String,
          title: t['title'] as String,
          subject: 'Scenario',
          description: '',
          deadline: t['due'] == null ? null : _time(t['due'] as String),
          estimatedMinutes: t['estimatedMinutes'] as int,
          completedMinutes: t['completedMinutes'] as int? ?? 0,
          assessmentWeightPercent: (t['weightPercent'] as num?)?.toDouble(),
          status: t['completed'] == true
              ? TaskStatus.completed
              : TaskStatus.active,
        ),
    ],
    availability: WeeklyAvailability(
      windows: [
        for (var i = 0; i < windows.length; i++)
          StudyWindow(id: 'w$i', range: _range(windows[i])),
      ],
      commitments: [
        for (var i = 0; i < commitments.length; i++)
          RecurringCommitment(
            id: 'c$i',
            title: commitments[i]['title'] as String? ?? 'Commitment',
            category: CommitmentCategory.other,
            range: _range(commitments[i]),
          ),
      ],
    ),
    now: _time(scenario['now'] as String),
    settings: PlannerSettings(
      horizonDays: s['horizonDays'] as int,
      maxSessionMinutes: s['maxSessionMinutes'] as int,
      minSessionMinutes: s['minSessionMinutes'] as int,
      breakMinutes: s['breakMinutes'] as int,
      dailyLimitMinutes: s['dailyLimitMinutes'] as int,
      perTaskDailyMinutes: s['perTaskDailyMinutes'] as int,
      daysOff: (s['daysOff'] as List).cast<int>().toSet(),
    ),
  );
}

Map<String, Object?> _encode(PlanProposal p) => {
  'from': _format(p.from),
  'to': _format(p.to),
  'sessions': [
    for (final s in p.sessions)
      {'taskId': s.taskId, 'start': _format(s.startsAt), 'minutes': s.minutes},
  ],
  'unplaced': [
    for (final u in p.unplaced)
      {'taskId': u.task.id, 'minutes': u.minutes, 'reason': u.reason.name},
  ],
};
