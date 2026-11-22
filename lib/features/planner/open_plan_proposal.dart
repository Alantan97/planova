import 'package:flutter/material.dart';

import '../../core/time/app_clock.dart';
import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/study_plan_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../services/planning/rule_based_planner.dart';
import '../availability/screens/availability_screen.dart';
import 'screens/plan_proposal_screen.dart';

/// Runs the rule-based planner for the next 7 days with the student's study
/// preferences ([settings]) and opens the proposal for review. Nothing is
/// saved until the student accepts it.
Future<void> openPlanProposal(
  BuildContext context, {
  required StudyPlanRepository plans,
  required TaskRepository tasks,
  required AvailabilityRepository availability,
  required AppClock clock,
  required PlannerSettings settings,
}) {
  final proposal = planWeek(
    tasks: tasks.tasks,
    availability: availability.availability,
    now: clock.now(),
    settings: settings,
  );
  // An earlier message (e.g. "Marked as missed") must not cover Accept.
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (routeContext) => PlanProposalScreen(
        proposal: proposal,
        repository: plans,
        settings: settings,
        onSetAvailability: () => Navigator.pushReplacement(
          routeContext,
          MaterialPageRoute<void>(
            builder: (_) => AvailabilityScreen(repository: availability),
          ),
        ),
      ),
    ),
  );
}
