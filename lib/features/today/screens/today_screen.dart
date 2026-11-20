import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/session_widgets.dart';
import '../../../core/widgets/task_card.dart';
import '../../../core/widgets/progress_summary.dart';
import '../../../data/repositories/availability_repository.dart';
import '../view_models/today_view_model.dart';
import '../widgets/get_started_card.dart';
import '../widgets/needs_input_section.dart';
import '../../courses/start_proforma_import.dart';
import '../../tasks/screens/task_details_screen.dart';
import '../../tasks/screens/task_form_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.viewModel,
    required this.availability,
    required this.onViewPlan,
  });
  final TodayViewModel viewModel;
  final AvailabilityRepository availability;
  final VoidCallback onViewPlan;
  @override
  Widget build(BuildContext context) {
    final sessions = viewModel.sessions;
    final tasks = viewModel.taskRepository;
    final samples = viewModel.studyRepository.showsSampleSessions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(viewModel.dateLabel),
        const SizedBox(height: 8),
        const PageHeading(title: 'Today’s overview'),
        const SizedBox(height: 20),
        if (GetStartedCard.isNeeded(tasks, availability)) ...[
          GetStartedCard(
            tasks: tasks,
            availability: availability,
            clock: viewModel.clock,
          ),
          const SizedBox(height: 28),
        ],
        if (NeedsInputSection.waiting(tasks).isNotEmpty) ...[
          NeedsInputSection(repository: tasks, clock: viewModel.clock),
          const SizedBox(height: 20),
        ],
        if (viewModel.nextSession != null)
          NextSessionCard(viewModel.nextSession!),
        const SizedBox(height: 20),
        const SectionTitle('Next deadline'),
        const SizedBox(height: 12),
        if (viewModel.upcomingTask != null)
          TaskCard(
            task: viewModel.upcomingTask!,
            now: viewModel.clock.now(),
            onTap: () => openTaskDetails(
              context,
              tasks,
              viewModel.clock,
              viewModel.upcomingTask!.id,
            ),
          )
        else if (tasks.tasks.isEmpty)
          _NoTasksPanel(viewModel: viewModel)
        else
          const Panel(
            child: Text('You are all caught up. Every saved task is complete.'),
          ),
        const SizedBox(height: 28),
        SectionTitle(
          'Your day',
          trailing: TextButton.icon(
            onPressed: onViewPlan,
            label: const Text('View plan'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            iconAlignment: IconAlignment.end,
          ),
        ),
        Text(
          samples ? viewModel.workloadLabel : 'No study sessions yet. Planova will plan them around your availability in a later version.',
          style: const TextStyle(
            color: planovaMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        ...sessions.map((session) => SessionRow(session)),
        if (samples) ...[
          const SizedBox(height: 24),
          const SectionTitle('Sample study week'),
          const SizedBox(height: 16),
          ProgressSummary(
            minutes: viewModel.completedMinutes,
            goalMinutes: viewModel.goalMinutes,
          ),
        ],
        const SizedBox(height: 24),
        DemoNote(samples: samples),
      ],
    );
  }
}

/// Shown only when no tasks exist at all, so "caught up" is never claimed
/// for a student who has not started.
class _NoTasksPanel extends StatelessWidget {
  const _NoTasksPanel({required this.viewModel});
  final TodayViewModel viewModel;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No tasks yet',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Import a course proforma to bring in your assessments, or add a task yourself.',
          style: TextStyle(color: planovaMuted, height: 1.45),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const ValueKey('today-import-proforma'),
              onPressed: () => startProformaImport(
                context,
                viewModel.taskRepository,
                viewModel.clock,
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 20),
              label: const Text('Import proforma'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('today-add-task'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TaskFormScreen(
                    repository: viewModel.taskRepository,
                    clock: viewModel.clock,
                  ),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add task'),
            ),
          ],
        ),
      ],
    ),
  );
}
