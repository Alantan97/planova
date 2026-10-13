import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/session_widgets.dart';
import '../../../core/widgets/task_card.dart';
import '../../../core/widgets/progress_summary.dart';
import '../view_models/today_view_model.dart';

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
        const SizedBox(height: 10),
        const Text(
          'Make room for progress.',
          style: TextStyle(
            fontSize: 38,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'A little focus. A step closer.',
          style: TextStyle(fontSize: 16, color: planovaMuted),
        ),
        const SizedBox(height: 24),
        if (viewModel.nextSession != null)
          NextSessionCard(viewModel.nextSession!),
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
        const SectionTitle('Coming up'),
        const SizedBox(height: 16),
        if (viewModel.upcomingTask != null)
          TaskCard(task: viewModel.upcomingTask!),
        const SizedBox(height: 24),
        const SectionTitle('Small steps add up'),
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
