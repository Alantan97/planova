import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../../../core/theme/app_theme.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/session_widgets.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../data/repositories/study_plan_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../open_plan_proposal.dart';
import '../widgets/plan_action_card.dart';
import '../widgets/record_session_sheet.dart';
import '../../progress/widgets/week_progress_card.dart';
import '../view_models/planner_view_model.dart';

/// All seven days fit on a phone. Tiles stay at least 48 px wide (the
/// Android touch-target guideline), borrowing up to 8 px of the page margin
/// on each side when needed. Only very narrow screens scroll.
Widget _weekStrip(double width, Widget Function(int index, double width) tile) {
  final roomy = (width - 6 * 4) / 7;
  if (roomy >= 48) {
    return Row(
      spacing: 4,
      children: [for (var i = 0; i < 7; i++) tile(i, roomy.clamp(48.0, 88.0))],
    );
  }
  final wide = width + 16;
  final snug = (wide - 6 * 2) / 7;
  if (snug >= 48) {
    return OverflowBox(
      fit: OverflowBoxFit.deferToChild,
      minWidth: wide,
      maxWidth: wide,
      child: Row(
        spacing: 2,
        children: [for (var i = 0; i < 7; i++) tile(i, snug)],
      ),
    );
  }
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(spacing: 4, children: [for (var i = 0; i < 7; i++) tile(i, 48)]),
  );
}

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({
    super.key,
    required this.viewModel,
    required this.availability,
    required this.tasks,
    this.plans,
  });
  final PlannerViewModel viewModel;
  final AvailabilityRepository availability;
  final TaskRepository tasks;

  /// Null in the demo build (sample sessions only, no planning).
  final StudyPlanRepository? plans;
  @override
  Widget build(BuildContext context) {
    final start = viewModel.weekStart;
    final end = DateTime(start.year, start.month, start.day + 6);
    final date = DateTime(
      start.year,
      start.month,
      start.day + viewModel.selectedDay,
    );
    final samples = viewModel.repository.showsSampleSessions;
    final studyMinutes = viewModel.sessions
        .where((s) => !s.commitment)
        .fold<int>(0, (total, s) => total + s.minutes);
    final range = start.month == end.month
        ? '${start.day}–${end.day} ${months[start.month - 1]} ${start.year}'
        : '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]} ${end.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'Your study plan',
          subtitle: 'Space for studying. Space for life.',
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                range,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous week',
              onPressed: viewModel.previousWeek,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: viewModel.nextWeek,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => _weekStrip(constraints.maxWidth, (
            index,
            width,
          ) {
            final day = DateTime(start.year, start.month, start.day + index);
            final selected = viewModel.selectedDay == index;
            final hasSession = viewModel.hasSessions(index);
            return SizedBox(
              width: width,
              child: Semantics(
                button: true,
                selected: selected,
                excludeSemantics: true,
                onTap: () => viewModel.selectDay(index),
                label:
                    '${weekdays[index]}, ${day.day} ${months[day.month - 1]} ${day.year}${hasSession ? ', has sessions' : ''}',
                child: Material(
                  color: selected
                      ? planovaActionOrange
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: ValueKey('day-$index'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => viewModel.selectDay(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          Text(
                            weekdays[index],
                            style: TextStyle(
                              color: selected ? planovaOnOrange : planovaInk,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: selected ? planovaOnOrange : planovaInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasSession
                                  ? (selected ? planovaOnOrange : planovaInk)
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        FeaturedPanel(
          child: Row(
            children: [
              const Icon(Icons.auto_stories_outlined, color: planovaOrange),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      samples
                          ? '$studyMinutes min of study'
                          : (plans?.hasPlan ?? false)
                          ? '${formatDuration(studyMinutes)} of study this day'
                          : 'No study plan yet',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      samples
                          ? 'Sample plan · Fixed commitments shown separately'
                          : (plans?.hasPlan ?? false)
                          ? 'Rule-based plan · Fixed commitments shown in grey'
                          : 'Planova fills your free study time for the next 7 days. You review it before it is saved.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    // With no plan yet, the main action sits right here
                    // instead of below the fold.
                    if (plans != null && !plans!.hasPlan) ...[
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        key: const ValueKey('create-plan'),
                        onPressed: () => openPlanProposal(
                          context,
                          plans: plans!,
                          tasks: tasks,
                          availability: availability,
                          clock: viewModel.clock,
                        ),
                        icon: const Icon(Icons.event_note_outlined),
                        label: const Text('Create my plan'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SectionTitle(
          '${weekdays[viewModel.selectedDay]}, ${date.day} ${months[date.month - 1]}',
        ),
        const SizedBox(height: 18),
        if (viewModel.sessions.isEmpty)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.wb_sunny_outlined,
                  color: planovaOrange,
                  size: 30,
                ),
                const SizedBox(height: 14),
                const Text(
                  'A little breathing room.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  samples
                      ? 'No sessions in this sample day. Browse 12–18 October to explore the demo plan.'
                      : 'No study sessions on this day.',
                  style: const TextStyle(color: planovaMuted, height: 1.5),
                ),
              ],
            ),
          )
        else
          ...viewModel.sessions.map(
            (session) => SessionRow(
              session,
              onTap: plans == null || session.commitment
                  ? null
                  : () => showRecordSessionSheet(
                      context,
                      plans: plans!,
                      session: session,
                    ),
            ),
          ),
        if (plans != null && plans!.hasPlan) ...[
          const SizedBox(height: 24),
          PlanActionCard(
            plans: plans!,
            tasks: tasks,
            availability: availability,
            clock: viewModel.clock,
          ),
        ],
        const SizedBox(height: 28),
        const SectionTitle('This week'),
        const SizedBox(height: 18),
        WeekProgressCard(
          studyRepository: viewModel.repository,
          taskRepository: tasks,
          clock: viewModel.clock,
        ),
        const SizedBox(height: 24),
        DemoNote(samples: samples),
      ],
    );
  }
}
