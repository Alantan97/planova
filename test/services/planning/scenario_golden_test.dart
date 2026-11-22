import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/services/planning/rule_based_planner.dart';

import '../../support/scenario_io.dart';

/// Runs the app's planner on the shared test weeks in ai/scenarios/ and
/// compares each plan with ai/scenarios/expected/. The Python copy of the
/// planner (ai/planova_scheduling/baseline.py) is checked against the same
/// files, so the evaluation baseline is exactly the app's planner.
///
/// After an intended planner change, rewrite the expected plans with:
///   $env:PLANOVA_UPDATE_GOLDEN='1'; flutter test test/services/planning/scenario_golden_test.dart
void main() {
  final update = Platform.environment['PLANOVA_UPDATE_GOLDEN'] == '1';
  final weeks = ScenarioWeek.all();

  test('Test weeks exist', () => expect(weeks, isNotEmpty));

  for (final week in weeks) {
    test('Planner matches the saved plan: ${week.id}', () {
      final plan = encodePlan(
        planWeek(
          tasks: week.tasks,
          availability: week.availability,
          now: week.now,
          settings: week.settings,
        ),
      );
      final expected = File('ai/scenarios/expected/${week.id}.json');
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
