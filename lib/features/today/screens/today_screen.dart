import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/session_widgets.dart';
import '../../../core/widgets/task_card.dart';
import '../../../core/widgets/progress_summary.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/study_plan_repository.dart';
import '../../../models/study_session.dart';
import '../../planner/open_plan_proposal.dart';
import '../../planner/widgets/record_session_sheet.dart';
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
    this.plans,
    this.profile,
  });
  final TodayViewModel viewModel;
  final AvailabilityRepository availability;

  /// Null in the demo build (sample sessions are read-only previews).
  final StudyPlanRepository? plans;

  /// Used for the greeting and to resume the guided journey.
  final ProfileRepository? profile;
  final VoidCallback onViewPlan;
  @override
  Widget build(BuildContext context) {
    final sessions = viewModel.sessions;
    final tasks = viewModel.taskRepository;
    final samples = viewModel.studyRepository.showsSampleSessions;
    final plans = this.plans;
    final now = viewModel.clock.now();
    final unrecorded = plans?.unrecordedBefore(now) ?? const <StudySession>[];
    final nextIsDeadline =
        viewModel.nextSession != null &&
        viewModel.upcomingTask != null &&
        viewModel.nextSession!.taskId == viewModel.upcomingTask!.id;
    VoidCallback? record(StudySession s) => plans == null || s.commitment
        ? null
        : () => showRecordSessionSheet(context, plans: plans, session: s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(viewModel.dateLabel),
        const SizedBox(height: 8),
        if (profile?.progress.displayName case final name?) ...[
          const SizedBox(height: 6),
          Text(
            'Hi, $name',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 20),
        if (GetStartedCard.isNeeded(tasks, availability)) ...[
          GetStartedCard(
            tasks: tasks,
            availability: availability,
            clock: viewModel.clock,
            profile: profile,
          ),
          const SizedBox(height: 28),
        ],
        if (NeedsInputSection.waiting(tasks).isNotEmpty) ...[
          NeedsInputSection(repository: tasks, clock: viewModel.clock),
          const SizedBox(height: 20),
        ],
        if (plans != null && plans.needsReplan) ...[
          _ReplanPrompt(
            onReplan: () => openPlanProposal(
              context,
              plans: plans,
              tasks: tasks,
              availability: availability,
              clock: viewModel.clock,
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (unrecorded.isNotEmpty) ...[
          SectionTitle('Did you do this? · ${unrecorded.length}'),
          const SizedBox(height: 6),
          const Text(
            'Record past sessions so your progress and plan stay accurate.',
            style: TextStyle(color: planovaMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (final s in unrecorded.take(3)) SessionRow(s, onTap: record(s)),
          const SizedBox(height: 12),
        ],
        if (viewModel.nextSession != null)
          NextSessionCard(
            viewModel.nextSession!,
            onOpen: record(viewModel.nextSession!),
          ),
        // The next session's card already shows that task; only show the
        // deadline section when it adds something new.
        if (!nextIsDeadline) ...[
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
              child: Text(
                'You are all caught up. Every saved task is complete.',
              ),
            ),
        ],
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
          samples || sessions.any((s) => !s.commitment)
              ? viewModel.workloadLabel
              : 'No study sessions today. Create a plan on the Plan tab.',
          style: const TextStyle(
            color: planovaMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        // The next session is already the featured card above.
        ...sessions
            .where((s) => s.id != viewModel.nextSession?.id)
            .map((session) => SessionRow(session, onTap: record(session))),
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

/// Shown after a session was missed or cut short, until a new plan is
/// accepted. Re-planning always goes through the review screen.
class _ReplanPrompt extends StatelessWidget {
  const _ReplanPrompt({required this.onReplan});
  final VoidCallback onReplan;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4EC),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your plan needs updating',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'A session was missed or cut short. Re-plan to find new time for the work that is left. You review the new plan first.',
          style: TextStyle(color: planovaMuted, height: 1.45),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('today-replan'),
          onPressed: onReplan,
          icon: const Icon(Icons.event_repeat_outlined),
          label: const Text('Re-plan the rest of the week'),
        ),
      ],
    ),
  );
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
