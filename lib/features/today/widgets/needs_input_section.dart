import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_task.dart';
import '../../tasks/widgets/due_date_sheet.dart';

/// Today's to-do list for missing information: active tasks that still have
/// no due date (usually imported with "Decide later"). Each row opens the
/// small due-date sheet. Hidden when nothing is missing.
class NeedsInputSection extends StatefulWidget {
  const NeedsInputSection({
    super.key,
    required this.repository,
    required this.clock,
  });
  final TaskRepository repository;
  final AppClock clock;

  /// Tasks that need input, oldest first so imports stay in course order.
  static List<AcademicTask> waiting(TaskRepository repository) => repository
      .tasks
      .where((task) => !task.isCompleted && !task.hasDeadline)
      .toList();

  @override
  State<NeedsInputSection> createState() => _NeedsInputSectionState();
}

class _NeedsInputSectionState extends State<NeedsInputSection> {
  static const _collapsedCount = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final waiting = NeedsInputSection.waiting(widget.repository);
    if (waiting.isEmpty) return const SizedBox.shrink();
    final shown = _showAll ? waiting : waiting.take(_collapsedCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Needs your input · ${waiting.length}'),
        const SizedBox(height: 6),
        const Text(
          'Add due dates so these can be prioritised and planned.',
          style: TextStyle(color: planovaMuted, height: 1.4),
        ),
        const SizedBox(height: 12),
        for (final task in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: const Color(0xFFFFF4EC),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey('needs-input-${task.id}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => showDueDateSheet(
                  context,
                  repository: widget.repository,
                  clock: widget.clock,
                  task: task,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${task.subject} · no due date yet',
                              style: const TextStyle(
                                color: planovaMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Add date',
                        style: TextStyle(
                          color: Color(0xFF8F3300),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (waiting.length > _collapsedCount)
          TextButton(
            key: const ValueKey('needs-input-toggle'),
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(_showAll ? 'Show fewer' : 'Show all ${waiting.length}'),
          ),
      ],
    );
  }
}
