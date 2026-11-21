import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../setup/screens/setup_screen.dart';

/// First-run checklist on Today. Each step is ticked from saved data, so it
/// stays accurate after restarts. Tapping a step, or "Continue setup", opens
/// the guided setup at that step. The card disappears once every step is done.
class GetStartedCard extends StatelessWidget {
  const GetStartedCard({
    super.key,
    required this.tasks,
    required this.availability,
    required this.clock,
    this.profile,
  });
  final TaskRepository tasks;
  final AvailabilityRepository availability;
  final AppClock clock;

  /// When set, offers to resume the full guided journey.
  final ProfileRepository? profile;

  /// Whether the card has anything left to show.
  static bool isNeeded(TaskRepository tasks, AvailabilityRepository week) =>
      tasks.semesters.isEmpty ||
      tasks.courses.isEmpty ||
      week.availability.windows.isEmpty;

  @override
  Widget build(BuildContext context) {
    void open(int step) => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SetupScreen(
          tasks: tasks,
          availability: availability,
          clock: clock,
          initialStep: step,
        ),
      ),
    );
    final steps = [
      (
        key: 'setup-semester',
        title: 'Add your semester',
        detail: 'Use the dates from your academic calendar.',
        done: tasks.semesters.isNotEmpty,
      ),
      (
        key: 'setup-courses',
        title: 'Import your course proformas',
        detail: 'Assessments and study hours are read for you.',
        done: tasks.courses.isNotEmpty,
      ),
      (
        key: 'setup-availability',
        title: 'Set your weekly availability',
        detail: 'When you can study, and what is already fixed.',
        done: availability.availability.windows.isNotEmpty,
      ),
    ];
    final done = steps.where((step) => step.done).length;
    final next = steps.indexWhere((step) => !step.done);
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
              onTap: () => open(index),
              child: InkWell(
                key: ValueKey(step.key),
                borderRadius: BorderRadius.circular(12),
                onTap: () => open(index),
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
          if (next >= 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('setup-continue'),
                onPressed: () => open(next),
                child: Text(done == 0 ? 'Start setup' : 'Continue setup'),
              ),
            ),
            if (profile != null)
              Center(
                child: TextButton(
                  key: const ValueKey('setup-guided'),
                  onPressed: () {
                    final saved = profile!.progress;
                    // Resume where the journey was left, or at this step.
                    profile!.save(
                      saved.copyWith(
                        completed: false,
                        step: saved.step >= 2 ? saved.step : next + 3,
                      ),
                    );
                  },
                  child: const Text('Use the step-by-step guide'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
