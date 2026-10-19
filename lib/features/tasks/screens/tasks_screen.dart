import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/task_card.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../core/time/app_clock.dart';
import 'task_details_screen.dart';
import 'task_form_screen.dart';
import '../../courses/screens/courses_screen.dart';

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
        PageHeading(
          title: 'Your tasks',
          subtitle:
              '${tasks.where((task) => !task.isCompleted).length} active · ${tasks.where((task) => task.isCompleted).length} completed',
          action: FilledButton.icon(
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
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add task'),
          ),
        ),
        const SizedBox(height: 20),
        Material(
          color: planovaSurface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    CoursesScreen(repository: repository, clock: clock),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.school_outlined, color: planovaInk, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Courses & semesters',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage courses and import proformas',
                          style: TextStyle(
                            color: planovaMuted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: planovaMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (tasks.isEmpty)
          const Panel(
            child: Text('A fresh start. Add your first academic task.'),
          )
        else
          ...tasks.map(
            (task) => TaskCard(
              task: task,
              now: clock.now(),
              onTap: () => openTaskDetails(context, repository, clock, task.id),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Tasks are saved locally. The study schedule and study-time totals are still sample data.',
          style: TextStyle(color: planovaMuted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}
