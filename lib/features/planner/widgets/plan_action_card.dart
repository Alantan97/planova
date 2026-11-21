import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../data/repositories/study_plan_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../open_plan_proposal.dart';

/// Plan-tab entry point for [openPlanProposal].
class PlanActionCard extends StatelessWidget {
  const PlanActionCard({
    super.key,
    required this.plans,
    required this.tasks,
    required this.availability,
    required this.clock,
  });
  final StudyPlanRepository plans;
  final TaskRepository tasks;
  final AvailabilityRepository availability;
  final AppClock clock;

  void _create(BuildContext context) => openPlanProposal(
    context,
    plans: plans,
    tasks: tasks,
    availability: availability,
    clock: clock,
  );

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome_motion_outlined, color: planovaOrange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Plan the next 7 days',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          plans.hasPlan
              ? 'Re-planning replaces upcoming planned sessions. You review the new plan before anything changes.'
              : 'Planova fills your free study time with sessions, earliest due date first. You review the plan before it is saved.',
          style: const TextStyle(color: planovaMuted, height: 1.45),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('create-plan'),
            onPressed: () => _create(context),
            icon: const Icon(Icons.event_note_outlined),
            label: Text(
              plans.hasPlan ? 'Re-plan the next 7 days' : 'Create my plan',
            ),
          ),
        ),
      ],
    ),
  );
}
