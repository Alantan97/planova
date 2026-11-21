import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../time/date_time_helpers.dart';
import 'study_components.dart';

class ProgressSummary extends StatelessWidget {
  const ProgressSummary({
    super.key,
    required this.minutes,
    required this.goalMinutes,
    this.featured = false,
    this.label = 'THIS WEEK · SAMPLE PROGRESS',
    this.goalWord = 'goal',
  });
  final int minutes;
  final int goalMinutes;
  final bool featured;

  /// Small heading, e.g. "THIS WEEK · STUDIED" for real recorded time.
  final String label;

  /// Word after the target, e.g. "goal" (samples) or "planned" (real plan).
  final String goalWord;

  @override
  Widget build(BuildContext context) {
    final progress = goalMinutes > 0
        ? (minutes / goalMinutes).clamp(0.0, 1.0)
        : 0.0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: featured ? Colors.white70 : planovaMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatDuration(minutes),
                style: TextStyle(
                  color: featured ? Colors.white : planovaInk,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' / ${formatDuration(goalMinutes)} $goalWord',
                style: TextStyle(
                  color: featured ? Colors.white70 : planovaMuted,
                  fontSize: 14,
                ),
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
            backgroundColor: featured ? Colors.white24 : planovaBorder,
            semanticsLabel:
                '${label.toLowerCase()}, ${formatDuration(minutes)} of ${formatDuration(goalMinutes)}',
            semanticsValue: '${(progress * 100).round()}%',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Every session counts.',
          style: TextStyle(color: featured ? Colors.white70 : planovaMuted),
        ),
      ],
    );
    return featured ? FeaturedPanel(child: content) : Panel(child: content);
  }
}
