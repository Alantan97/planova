import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../models/weekly_availability.dart';
import '../../../services/planning/free_study_slots.dart';
import 'time_block_form.dart';

/// Lists study windows and recurring commitments, and explains the free time
/// left for study. Nothing here generates study sessions yet.
class AvailabilityScreen extends StatelessWidget {
  const AvailabilityScreen({super.key, required this.repository});
  final AvailabilityRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weekly availability')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: repository,
            builder: (context, _) => _content(context),
          ),
        ),
      ),
    ),
  );

  Widget _content(BuildContext context) {
    final week = repository.availability;
    final slots = freeStudySlots(week);
    final free = slots.fold(0, (total, slot) => total + slot.minutes);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Your normal week.',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          'Add when you usually study and what is already fixed, such as '
          'classes, clubs, work or personal time. Commitments always take '
          'priority over study windows.',
          style: TextStyle(color: planovaMuted, height: 1.5),
        ),
        const SizedBox(height: 24),
        FeaturedPanel(
          child: Row(
            children: [
              const Icon(Icons.hourglass_bottom_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      week.windows.isEmpty
                          ? 'No study time yet'
                          : '${formatDuration(free)} free for study each week',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      week.windows.isEmpty
                          ? 'Add a study window to see your free time.'
                          : 'Study windows minus commitments · not a schedule yet',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionTitle('When you can study'),
        const SizedBox(height: 12),
        if (week.windows.isEmpty)
          const _Empty('No study windows yet. Example: weekdays 20:00–22:00.'),
        for (final window in week.windows)
          _BlockTile(
            key: ValueKey('window-${window.id}'),
            icon: Icons.menu_book_outlined,
            title:
                '${formatWeekdays(window.range.weekdays)} · ${_times(window.range)}',
            subtitle:
                '${formatDuration(window.range.minutesPerOccurrence)} each time',
            onEdit: () =>
                _open(context, TimeBlockForm.window(repository, window)),
            onDelete: () => _delete(
              context,
              'this study window',
              () => repository.deleteWindow(window.id),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          key: const ValueKey('add-study-window'),
          onPressed: () => _open(context, TimeBlockForm.window(repository)),
          icon: const Icon(Icons.add),
          label: const Text('Add study window'),
        ),
        const SizedBox(height: 28),
        const SectionTitle('Recurring commitments'),
        const SizedBox(height: 12),
        if (week.commitments.isEmpty)
          const _Empty(
            'No commitments yet. Add classes and anything else fixed.',
          ),
        for (final commitment in week.commitments)
          _BlockTile(
            key: ValueKey('commitment-${commitment.id}'),
            icon: Icons.event_busy_outlined,
            title: commitment.title,
            subtitle:
                '${commitment.category.label} · '
                '${formatWeekdays(commitment.range.weekdays)} · '
                '${_times(commitment.range)}',
            onEdit: () => _open(
              context,
              TimeBlockForm.commitment(repository, commitment),
            ),
            onDelete: () => _delete(
              context,
              '“${commitment.title}”',
              () => repository.deleteCommitment(commitment.id),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          key: const ValueKey('add-commitment'),
          onPressed: () => _open(context, TimeBlockForm.commitment(repository)),
          icon: const Icon(Icons.add),
          label: const Text('Add commitment'),
        ),
        if (week.windows.isNotEmpty) ...[
          const SizedBox(height: 28),
          const SectionTitle('Free time by day'),
          const SizedBox(height: 8),
          const Text(
            'What a future study planner could use: your study windows with '
            'commitments removed.',
            style: TextStyle(color: planovaMuted, height: 1.5),
          ),
          const SizedBox(height: 12),
          for (var day = 1; day <= 7; day++) _DayRow(day: day, slots: slots),
        ],
        const SizedBox(height: 24),
        const Text(
          'Saved locally on this device. Planova does not create study '
          'sessions from this yet.',
          style: TextStyle(color: planovaMuted, fontSize: 12),
        ),
      ],
    );
  }

  static String _times(WeeklyTimeRange range) =>
      '${formatClock(range.startMinute)}–${formatClock(range.endMinute)}';

  void _open(BuildContext context, Widget form) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => form));

  Future<void> _delete(
    BuildContext context,
    String label,
    Future<void> Function() delete,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete from your week?'),
        content: Text('Remove $label? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await delete();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(academicSaveError(error))));
      }
    }
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      child: Row(
        children: [
          Icon(icon, color: planovaOrange),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: planovaMuted, height: 1.4),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Options for $title',
            icon: const Icon(Icons.more_horiz, color: planovaMuted),
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.slots});
  final int day;
  final List<FreeSlot> slots;

  @override
  Widget build(BuildContext context) {
    final today = slots.where((slot) => slot.weekday == day).toList();
    final minutes = today.fold(0, (total, slot) => total + slot.minutes);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              weekdays[day - 1],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              today.isEmpty
                  ? 'No free study time'
                  : today
                        .map(
                          (slot) =>
                              '${formatClock(slot.startMinute)}–${formatClock(slot.endMinute)}',
                        )
                        .join(', '),
              style: TextStyle(
                color: today.isEmpty ? planovaMuted : planovaInk,
                height: 1.4,
              ),
            ),
          ),
          if (minutes > 0)
            Text(
              formatDuration(minutes),
              style: const TextStyle(color: planovaMuted),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(color: planovaMuted, height: 1.5)),
  );
}
