import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/session_widgets.dart';
import '../../../core/widgets/task_card.dart';
import '../../../core/widgets/progress_summary.dart';
import '../view_models/today_view_model.dart';
import '../../tasks/screens/task_details_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.viewModel,
    required this.onViewPlan,
  });
  final TodayViewModel viewModel;
  final VoidCallback onViewPlan;
  @override
  Widget build(BuildContext context) {
    final sessions = viewModel.sessions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(viewModel.dateLabel),
        const SizedBox(height: 8),
        const PageHeading(title: 'Today’s overview'),
        const SizedBox(height: 20),
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
              viewModel.taskRepository,
              viewModel.clock,
              viewModel.upcomingTask!.id,
            ),
          )
        else
          const Panel(
            child: Text(
              'You are all caught up. Add a task from the Tasks tab.',
            ),
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
          viewModel.workloadLabel,
          style: TextStyle(color: planovaMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...sessions.map((session) => SessionRow(session)),
        const SizedBox(height: 24),
        const SectionTitle('Sample study week'),
        const SizedBox(height: 16),
        ProgressSummary(
          minutes: viewModel.completedMinutes,
          goalMinutes: viewModel.goalMinutes,
        ),
        const SizedBox(height: 24),
        const DemoNote(),
      ],
    );
  }
}
