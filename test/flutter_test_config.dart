import 'dart:async';

import 'package:planova/services/planning/balanced_plan_runner.dart';

/// Runs before every test file. Widget tests use fake time, which cannot
/// wait for a real background isolate, so the balanced planner runs
/// immediately here. test/features/planner/balanced_plan_test.dart checks
/// the real isolate runner separately.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  runBalancedPlan = (request) async => planBalancedFor(request);
  await testMain();
}
