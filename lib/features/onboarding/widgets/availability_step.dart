import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../models/weekly_availability.dart';
import '../../../services/planning/free_study_slots.dart';
import '../../availability/screens/availability_screen.dart';
import '../../availability/screens/time_block_form.dart';

import 'step_intro.dart';

/// A ready-made weekly study window the student can switch on with one tap.
/// Each preset is saved as a normal study window with a fixed ID, so it can
/// be edited or removed later on the Weekly availability screen.
class AvailabilityPreset {
  const AvailabilityPreset(
    this.id,
    this.label,
    this.days,
    this.start,
    this.end,
  );
  final String id;
  final String label;
  final List<int> days;
  final int start;
  final int end;

  WeeklyTimeRange get range =>
      WeeklyTimeRange(weekdays: days, startMinute: start, endMinute: end);
  String get detail =>
      '${formatWeekdays(days)}, ${formatClock(start)}–${formatClock(end)}';

  static const all = [
    AvailabilityPreset(
      'preset-weekday-evenings',
      'Weekday evenings',
      [1, 2, 3, 4, 5],
      20 * 60,
      22 * 60,
    ),
    AvailabilityPreset(
      'preset-weekday-afternoons',
      'Weekday afternoons',
      [1, 2, 3, 4, 5],
      14 * 60,
      17 * 60,
    ),
    AvailabilityPreset(
      'preset-weekend-mornings',
      'Weekend mornings',
      [6, 7],
      9 * 60,
      12 * 60,
    ),
  ];
}

/// One-tap presets, custom times and commitments, with the weekly total.
class AvailabilityStep extends StatelessWidget {
  const AvailabilityStep({super.key, required this.availability});
  final AvailabilityRepository availability;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: availability,
    builder: (context, _) {
      final week = availability.availability;
      final free = freeMinutesPerWeek(week);
      final presetIds = AvailabilityPreset.all.map((p) => p.id).toSet();
      final custom = week.windows.where((w) => !presetIds.contains(w.id));
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          const StepIntro(
            'When can you study?',
            'Pick what fits a normal week. You can fine-tune times later.',
          ),
          for (final preset in AvailabilityPreset.all)
            _presetTile(context, preset),
          _ChoiceTile(
            key: const ValueKey('setup-custom-times'),
            title: 'Custom times',
            detail: custom.isEmpty
                ? 'Choose days and times yourself'
                : '${custom.length} custom ${custom.length == 1 ? 'window' : 'windows'}',
            selected: custom.isNotEmpty,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AvailabilityScreen(repository: availability),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Fixed in your week',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Classes, clubs, work. Study is never planned over these.',
            style: TextStyle(color: planovaMuted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          for (final c in week.commitments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: planovaSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${c.title} · ${formatWeekdays(c.range.weekdays)} ${formatClock(c.range.startMinute)}–${formatClock(c.range.endMinute)}',
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('setup-add-commitment'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TimeBlockForm.commitment(availability),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add commitment'),
            ),
          ),
          const SizedBox(height: 16),
          FeaturedPanel(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Free for study each week',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                Text(
                  week.windows.isEmpty ? '—' : formatDuration(free),
                  key: const ValueKey('setup-free-time'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _presetTile(BuildContext context, AvailabilityPreset preset) {
    final on = availability.availability.windows.any((w) => w.id == preset.id);
    return _ChoiceTile(
      key: ValueKey(preset.id),
      title: preset.label,
      detail: preset.detail,
      selected: on,
      trailing: Icon(
        on ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: on ? planovaActionOrange : planovaMuted,
      ),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          if (on) {
            await availability.deleteWindow(preset.id);
          } else {
            await availability.saveWindow(
              StudyWindow(id: preset.id, range: preset.range),
            );
          }
        } catch (error) {
          messenger.showSnackBar(
            SnackBar(content: Text(academicSaveError(error))),
          );
        }
      },
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.title,
    required this.detail,
    required this.selected,
    required this.trailing,
    required this.onTap,
  });
  final String title;
  final String detail;
  final bool selected;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFFFF4EC) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? planovaActionOrange : planovaBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: planovaMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
