import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../availability/screens/availability_screen.dart';
import '../../courses/screens/courses_screen.dart';

/// First-run checklist, following docs/workflow.md §3: semester → courses →
/// availability. Each step is ticked from saved data, so it stays accurate
/// after restarts. The card disappears once every step is done.
class GetStartedCard extends StatelessWidget {
  const GetStartedCard({
    super.key,
    required this.tasks,
    required this.availability,
    required this.clock,
  });
  final TaskRepository tasks;
  final AvailabilityRepository availability;
  final AppClock clock;

  /// Whether the card has anything left to show.
  static bool isNeeded(TaskRepository tasks, AvailabilityRepository week) =>
      tasks.semesters.isEmpty ||
      tasks.courses.isEmpty ||
      week.availability.windows.isEmpty;

  @override
  Widget build(BuildContext context) {
    void openCourses() => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CoursesScreen(repository: tasks, clock: clock),
      ),
    );
    final steps = [
      (
        key: 'setup-semester',
        title: 'Add your semester',
        detail: 'Use the dates from your academic calendar.',
        done: tasks.semesters.isNotEmpty,
        open: openCourses,
      ),
      (
        key: 'setup-courses',
        title: 'Import a proforma or add a course',
        detail:
            'Bring in assessments and weekly learning from your course PDF.',
        done: tasks.courses.isNotEmpty,
        open: openCourses,
      ),
      (
        key: 'setup-availability',
        title: 'Set your weekly availability',
        detail: 'When you can study, and what is already fixed.',
        done: availability.availability.windows.isNotEmpty,
        open: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AvailabilityScreen(repository: availability),
          ),
        ),
      ),
    ];
    final done = steps.where((step) => step.done).length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('GET STARTED · $done OF ${steps.length} DONE'),
          const SizedBox(height: 8),
          const Text(
            'Set up Planova for your semester.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final (index, step) in steps.indexed)
            Semantics(
              button: true,
              label:
                  'Step ${index + 1}: ${step.title}${step.done ? ', done' : ''}',
              excludeSemantics: true,
              onTap: step.open,
              child: InkWell(
                key: ValueKey(step.key),
                borderRadius: BorderRadius.circular(12),
                onTap: step.open,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        step.done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: step.done ? planovaActionOrange : planovaMuted,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: step.done ? planovaMuted : planovaInk,
                                decoration: step.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (!step.done) ...[
                              const SizedBox(height: 2),
                              Text(
                                step.detail,
                                style: const TextStyle(
                                  color: planovaMuted,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: planovaMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
