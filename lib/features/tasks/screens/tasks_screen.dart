import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/task_card.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../core/time/demo_clock.dart';
import 'task_details_screen.dart';
import 'task_form_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.repository, required this.clock});
  final TaskRepository repository;
  final AppClock clock;

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
        FilledButton.icon(
          onPressed: () async {
            final saved = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TaskFormScreen(repository: repository, clock: clock),
              ),
            );
            if (saved == true && context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Task added.')));
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: planovaOrange,
            foregroundColor: planovaOnOrange,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add task'),
        ),
        const SizedBox(height: 12),
        Text(
          '${tasks.where((task) => !task.isCompleted).length} active · ${tasks.where((task) => task.isCompleted).length} completed',
          style: const TextStyle(color: planovaMuted),
        ),
        const SizedBox(height: 16),
        if (tasks.isEmpty)
          const Panel(
            child: Text('A fresh start. Add your first academic task.'),
          )
        else
          ...tasks.map(
            (task) => TaskCard(
              task: task,
              onTap: () => openTaskDetails(context, repository, clock, task.id),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Prototype · Tasks are stored for this app session. Restarting restores the sample data.',
          style: TextStyle(color: planovaMuted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}
