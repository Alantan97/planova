import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/progress_summary.dart';
import '../../../data/repositories/study_plan_repository.dart';
import '../../../data/repositories/study_repository.dart';
import '../../../data/repositories/task_repository.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          title: 'Your progress',
          subtitle: samples
              ? 'A snapshot of your sample study week.'
              : 'Small steps add up.',
        ),
        const SizedBox(height: 20),
        if (!samples && studyRepository is StudyPlanRepository)
          ProgressSummary(
            featured: true,
            label: 'THIS WEEK · STUDIED',
            goalWord: 'planned',
            minutes: studyRepository.completedMinutesInWeek(clock.now()),
            goalMinutes: (studyRepository as StudyPlanRepository)
                .plannedMinutesInWeek(clock.now()),
          )
        else if (samples)
          ProgressSummary(
            featured: true,
            minutes: studyRepository.completedMinutesInWeek(clock.now()),
            goalMinutes: studyRepository.weeklyGoalMinutes,
          )
        else
          const FeaturedPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.timer_outlined),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No study plan yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Create a plan on the Plan tab, then record each session here. Task completion below is real.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: planovaOrange,
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                '${taskRepository.tasks.where((task) => task.isCompleted).length} of ${taskRepository.tasks.length} ${taskRepository.tasks.length == 1 ? 'task' : 'tasks'} completed',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Across your saved tasks.',
                style: TextStyle(color: planovaMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        DemoNote(samples: samples),
      ],
    );
  }
}
