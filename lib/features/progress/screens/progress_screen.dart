import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/progress_summary.dart';
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
        const Eyebrow('NOTICE HOW FAR YOU HAVE COME'),
        const SizedBox(height: 10),
        Text(
          'Small steps add up.',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        const SizedBox(height: 12),
        Text(
          samples
              ? 'A snapshot of your sample study week.'
              : 'A snapshot of your saved tasks.',
          style: const TextStyle(color: planovaMuted, fontSize: 16),
        ),
        const SizedBox(height: 24),
        if (samples)
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
                        'Study time is not tracked yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Recording study sessions arrives with the planner. Task completion below is real.',
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
                '${taskRepository.tasks.where((task) => task.isCompleted).length} of ${taskRepository.tasks.length} tasks completed',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Across your saved tasks. Completing a task does not add study hours.',
                style: TextStyle(color: planovaMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Make space to reflect'),
              SizedBox(height: 12),
              Text(
                'Which study session helped you most? What would you change next week?',
                style: TextStyle(color: planovaMuted, height: 1.5),
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
