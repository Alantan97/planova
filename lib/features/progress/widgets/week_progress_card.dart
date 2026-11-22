import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/progress_summary.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/study_plan_repository.dart';
import '../../../data/repositories/study_repository.dart';
import '../../../data/repositories/task_repository.dart';

/// "This week" on the Plan tab: recorded study time against the plan, and
/// how many saved tasks are finished. Replaces the separate Progress tab.
class WeekProgressCard extends StatelessWidget {
  const WeekProgressCard({
    super.key,
    required this.studyRepository,
    required this.taskRepository,
    required this.clock,
  });
  final StudyRepository studyRepository;
  final TaskRepository taskRepository;
  final AppClock clock;

  @override
  Widget build(BuildContext context) {
    final samples = studyRepository.showsSampleSessions;
    final now = clock.now();
    final plans = studyRepository is StudyPlanRepository
        ? studyRepository as StudyPlanRepository
        : null;
    final tasks = taskRepository.tasks;
    final done = tasks.where((task) => task.isCompleted).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (samples)
          ProgressSummary(
            minutes: studyRepository.completedMinutesInWeek(now),
            goalMinutes: studyRepository.weeklyGoalMinutes,
          )
        else if (plans != null && plans.hasPlan)
          ProgressSummary(
            label: 'THIS WEEK · STUDIED',
            goalWord: 'planned',
            minutes: plans.completedMinutesInWeek(now),
            goalMinutes: plans.plannedMinutesInWeek(now),
          ),
        if (samples || (plans?.hasPlan ?? false)) const SizedBox(height: 12),
        Panel(
          child: Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: planovaOrange),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$done of ${tasks.length} '
                      '${tasks.length == 1 ? 'task' : 'tasks'} completed',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Across your saved tasks.',
                      style: TextStyle(color: planovaMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
