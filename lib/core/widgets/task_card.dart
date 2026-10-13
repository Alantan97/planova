import 'package:flutter/material.dart';

import '../../models/academic_task.dart';
import '../theme/app_theme.dart';
import '../time/demo_clock.dart';
import 'study_components.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task});
  final AcademicTask task;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showTaskDetails(context, task),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.subject,
                style: const TextStyle(color: planovaMuted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                task.isCompleted
                    ? 'Completed · Sample task'
                    : 'Due ${task.deadline.day} ${months[task.deadline.month - 1]} · ${formatDuration(task.estimatedMinutes)} estimated',
                style: const TextStyle(color: planovaMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: task.progress,
                minHeight: 4,
                color: planovaOrange,
                backgroundColor: const Color(0xFFE6E6E6),
                semanticsLabel: '${task.title} progress',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void showTaskDetails(BuildContext context, AcademicTask task) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Eyebrow('SAMPLE TASK'),
            const SizedBox(height: 12),
            Text(
              task.title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(task.subject, style: const TextStyle(color: planovaMuted)),
            const SizedBox(height: 20),
            Text(task.description, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 20),
            Panel(
              child: Text(
                'Due ${task.deadline.day} ${months[task.deadline.month - 1]} ${task.deadline.year}\n${formatDuration(task.estimatedMinutes)} estimated · ${(task.progress * 100).round()}% complete\nDifficulty: ${task.difficulty.name}\nImportance: ${task.importance.name}',
                style: const TextStyle(height: 1.8),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Read-only sample data. Task editing will be added in the next development phase.',
              style: TextStyle(color: planovaMuted, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
