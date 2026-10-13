import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../time/demo_clock.dart';
import 'study_components.dart';

class ProgressSummary extends StatelessWidget {
  const ProgressSummary({
    super.key,
    required this.minutes,
    required this.goalMinutes,
  });
  final int minutes;
  final int goalMinutes;

  @override
  Widget build(BuildContext context) {
    final progress = goalMinutes > 0
        ? (minutes / goalMinutes).clamp(0.0, 1.0)
        : 0.0;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('THIS WEEK · SAMPLE PROGRESS'),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatDuration(minutes),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' / ${formatDuration(goalMinutes)} goal',
                  style: const TextStyle(color: planovaMuted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: planovaOrange,
              backgroundColor: const Color(0xFFE6E6E6),
              semanticsLabel: 'Sample weekly progress',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Every session counts.',
            style: TextStyle(color: planovaMuted),
          ),
        ],
      ),
    );
  }
}
