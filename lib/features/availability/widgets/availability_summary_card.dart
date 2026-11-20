import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../services/planning/free_study_slots.dart';
import '../screens/availability_screen.dart';

/// Plan-tab entry point: a short summary plus a button to edit the week.
class AvailabilitySummaryCard extends StatelessWidget {
  const AvailabilitySummaryCard({super.key, required this.repository});
  final AvailabilityRepository repository;

  @override
  Widget build(BuildContext context) {
    final week = repository.availability;
    final free = freeMinutesPerWeek(week);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available_outlined, color: planovaOrange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Weekly availability',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            week.isEmpty
                ? 'Tell Planova when you usually study and what is already fixed in your week.'
                : '${_count(week.windows.length, 'study window')} · '
                      '${_count(week.commitments.length, 'commitment')} · '
                      '${formatDuration(free)} free each week',
            style: const TextStyle(color: planovaMuted, height: 1.45),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const ValueKey('open-availability'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AvailabilityScreen(repository: repository),
              ),
            ),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text(
              week.isEmpty ? 'Set availability' : 'Edit availability',
            ),
          ),
        ],
      ),
    );
  }

  static String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
}
