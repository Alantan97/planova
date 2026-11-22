import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/services/planning/ga_planner.dart';
import 'package:planova/services/planning/rule_based_planner.dart';

import '../../support/scenario_io.dart';

/// The app's balanced (GA) planner must be the GA that was evaluated:
/// on every shared test week it must reproduce the Python GA's saved plan
/// and score exactly (ai/scenarios/expected_ga/, written by
/// ai/export_ga_golden.py).
void main() {
  final weeks = ScenarioWeek.all();

  group('Random numbers match the Python generator', () {
    test('First values for seeds 0 and 42', () {
      // Same values are checked in ai/tests/test_ga.py.
      final a = PlanRng(0);
      final b = PlanRng(42);
      expect([for (var i = 0; i < 3; i++) a.nextU32()], _seed0);
      expect([for (var i = 0; i < 3; i++) b.nextU32()], _seed42);
    });
  });

  for (final week in weeks) {
    test('GA matches the Python GA: ${week.id}', () {
      final expected = jsonDecode(
        File('ai/scenarios/expected_ga/${week.id}.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final result = planWeekBalanced(
        tasks: week.tasks,
        availability: week.availability,
        now: week.now,
        settings: week.settings,
        seed: expected['seed'] as int,
      );
      const config = BalancedPlannerConfig();
      expect(expected['population'], config.population);
      expect(expected['generations'], config.generations);
      expect(expected['startFromBaseline'], config.startFromBaseline);
      expect(encodePlan(result.proposal), {
        for (final key in ['from', 'to', 'sessions', 'unplaced'])
          key: expected[key],
      });
      expect(result.score.total, expected['fitness']);
    });
  }

  test('Never worse than the rule-based plan on the goal', () {
    for (final week in weeks) {
      final rules = planWeek(
        tasks: week.tasks,
        availability: week.availability,
        now: week.now,
        settings: week.settings,
      );
      final rulesScore = scorePlanGoal(
        proposal: rules,
        tasks: week.tasks,
        availability: week.availability,
        now: week.now,
        settings: week.settings,
      );
      final balanced = planWeekBalanced(
        tasks: week.tasks,
        availability: week.availability,
        now: week.now,
        settings: week.settings,
        config: const BalancedPlannerConfig(population: 10, generations: 5),
      );
      expect(
        balanced.score.total,
        lessThanOrEqualTo(rulesScore.total),
        reason: week.id,
      );
      expect(
        balanced.score.missedMinutes,
        lessThanOrEqualTo(rulesScore.missedMinutes),
        reason: week.id,
      );
    }
  });

  test('Session IDs and details match the rule-based planner style', () {
    final week = weeks.firstWhere((w) => w.id == 'd02-normal-week');
    final plan = planWeekBalanced(
      tasks: week.tasks,
      availability: week.availability,
      now: week.now,
      settings: week.settings,
      config: const BalancedPlannerConfig(population: 10, generations: 5),
    ).proposal;
    for (final s in plan.sessions) {
      expect(s.id, planSessionId(s.startsAt, s.taskId!));
      final task = week.tasks.firstWhere((t) => t.id == s.taskId);
      expect(s.title, task.title);
      expect(s.subject, task.subject);
    }
  });
}

const _seed0 = <int>[2831543865, 3042595768, 445164014];
const _seed42 = <int>[289363370, 2328323471, 2829082676];
