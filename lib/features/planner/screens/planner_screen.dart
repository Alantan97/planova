import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/demo_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/session_widgets.dart';
import '../view_models/planner_view_model.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key, required this.viewModel});
  final PlannerViewModel viewModel;
  @override
  Widget build(BuildContext context) {
    final start = viewModel.weekStart;
    final end = DateTime(start.year, start.month, start.day + 6);
    final date = DateTime(
      start.year,
      start.month,
      start.day + viewModel.selectedDay,
    );
    final studyMinutes = viewModel.sessions
        .where((s) => !s.commitment)
        .fold<int>(0, (total, s) => total + s.minutes);
    final range = start.month == end.month
        ? '${start.day}–${end.day} ${months[start.month - 1]} ${start.year}'
        : '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]} ${end.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('A LITTLE STRUCTURE, MORE FOCUS'),
        const SizedBox(height: 10),
        const Text(
          'Your study plan.',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Space for studying. Space for life.',
          style: TextStyle(fontSize: 16, color: planovaMuted),
        ),
        const SizedBox(height: 24),
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
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 4,
              children: List.generate(7, (index) {
                final day = DateTime(
                  start.year,
                  start.month,
                  start.day + index,
                );
                final selected = viewModel.selectedDay == index;
                final hasSession = viewModel.hasSessions(index);
                return SizedBox(
                  width: ((constraints.maxWidth - 24) / 7).clamp(44.0, 88.0),
                  child: Semantics(
                    selected: selected,
                    label:
                        '${weekdays[index]} ${day.day} ${months[day.month - 1]}',
                    child: Material(
                      color: selected ? planovaOrange : const Color(0xFFF5F5F5),
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
                                  color: selected
                                      ? planovaOnOrange
                                      : planovaInk,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: selected
                                      ? planovaOnOrange
                                      : planovaInk,
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
                                      ? (selected
                                            ? planovaOnOrange
                                            : planovaInk)
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
          ),
        ),
        const SizedBox(height: 24),
        Panel(
          child: Row(
            children: [
              const Icon(Icons.auto_stories_outlined, color: planovaOrange),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$studyMinutes min of study',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fixed commitments shown separately',
                      style: TextStyle(color: planovaMuted, fontSize: 12),
                    ),
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
          const Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wb_sunny_outlined, color: planovaOrange, size: 30),
                SizedBox(height: 14),
                Text(
                  'A little breathing room.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'No sessions in this sample day. Browse 12–18 October to explore the demo plan.',
                  style: TextStyle(color: planovaMuted, height: 1.5),
                ),
              ],
            ),
          )
        else
          ...viewModel.sessions.map((session) => SessionRow(session)),
        const SizedBox(height: 24),
        const DemoNote(),
      ],
    );
  }
}
