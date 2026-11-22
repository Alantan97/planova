import 'package:flutter/foundation.dart';

import '../../models/academic_task.dart';
import '../../models/weekly_availability.dart';
import 'ga_planner.dart';
import 'rule_based_planner.dart';

/// Everything the balanced (GA) planner needs, as plain data so it can be
/// sent to a background isolate.
class PlanRequest {
  const PlanRequest({
    required this.tasks,
    required this.availability,
    required this.now,
    required this.settings,
  });
  final List<AcademicTask> tasks;
  final WeeklyAvailability availability;
  final DateTime now;
  final PlannerSettings settings;
}

/// Runs the balanced planner for [request]. Seed 0, so the same inputs
/// always give the same plan.
BalancedPlanResult planBalancedFor(PlanRequest request) => planWeekBalanced(
  tasks: request.tasks,
  availability: request.availability,
  now: request.now,
  settings: request.settings,
);

typedef BalancedPlanRunner = Future<BalancedPlanResult> Function(
  PlanRequest request,
);

/// Runs the balanced planner in a background isolate, so the screen keeps
/// animating while the GA searches (on the web, `compute` runs it on the
/// main thread instead).
Future<BalancedPlanResult> planBalancedInBackground(PlanRequest request) =>
    compute(planBalancedFor, request);

/// How the app runs the balanced planner. Widget tests replace this with an
/// immediate runner in test/flutter_test_config.dart, because fake test
/// time cannot wait for a real isolate.
BalancedPlanRunner runBalancedPlan = planBalancedInBackground;
