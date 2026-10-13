import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/task_card.dart';
import '../../../data/repositories/task_repository.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.repository});
  final TaskRepository repository;

  @override
  Widget build(BuildContext context) {
    final tasks = repository.tasks.toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('A CLEARER VIEW OF YOUR WORKLOAD'),
        const SizedBox(height: 10),
        Text(
          'Your academic tasks.',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        const SizedBox(height: 12),
        const Text(
          'One place for assignments, revision, and the next small step.',
          style: TextStyle(color: planovaMuted, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 24),
        Text(
          '${tasks.where((task) => !task.isCompleted).length} active · ${tasks.where((task) => task.isCompleted).length} completed',
          style: const TextStyle(color: planovaMuted),
        ),
        const SizedBox(height: 16),
        ...tasks.map((task) => TaskCard(task: task)),
        const SizedBox(height: 12),
        const DemoNote(),
      ],
    );
  }
}
