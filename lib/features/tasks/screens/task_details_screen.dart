import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/demo_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/task_repository.dart';
import 'task_form_screen.dart';

void openTaskDetails(
  BuildContext context,
  TaskRepository repository,
  AppClock clock,
  String id,
) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          TaskDetailsScreen(repository: repository, clock: clock, taskId: id),
    ),
  );
}

class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({
    super.key,
    required this.repository,
    required this.clock,
    required this.taskId,
  });
  final TaskRepository repository;
  final AppClock clock;
  final String taskId;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool _busy = false;

  Future<void> _complete(bool completed) async {
    setState(() => _busy = true);
    try {
      await widget.repository.setCompleted(widget.taskId, completed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completed
                  ? 'Task completed. Well done!'
                  : 'Task moved back to active.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this task. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text(
          'This removes the task and its planned sample study sessions. Recorded study time is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.delete(widget.taskId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Task deleted.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete this task. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final task = widget.repository.taskById(widget.taskId);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Task details'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: task == null
                  ? const Text('This task has been removed.')
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Eyebrow('ACADEMIC TASK'),
                        const SizedBox(height: 12),
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.subject,
                          style: const TextStyle(
                            color: planovaMuted,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.isCompleted
                                    ? 'Completed'
                                    : task.deadline.isBefore(widget.clock.now())
                                    ? 'Overdue'
                                    : 'In progress',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: task.progress,
                                color: planovaOrange,
                                backgroundColor: const Color(0xFFE6E6E6),
                                semanticsLabel: 'Task progress',
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${(task.progress * 100).round()}% complete · ${formatDuration(task.completedMinutes)} recorded',
                                style: const TextStyle(color: planovaMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Panel(
                          child: Text(
                            'Due ${task.deadline.day} ${months[task.deadline.month - 1]} ${task.deadline.year} at ${TimeOfDay.fromDateTime(task.deadline).format(context)}\n${formatDuration(task.estimatedMinutes)} estimated\nDifficulty: ${task.difficulty.name}\nImportance: ${task.importance.name}',
                            style: const TextStyle(height: 1.8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          task.description.isEmpty
                              ? 'No description added.'
                              : task.description,
                          style: const TextStyle(height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _complete(!task.isCompleted),
                          style: FilledButton.styleFrom(
                            backgroundColor: planovaOrange,
                            foregroundColor: planovaOnOrange,
                          ),
                          icon: Icon(
                            task.isCompleted
                                ? Icons.undo_rounded
                                : Icons.check_rounded,
                          ),
                          label: Text(
                            task.isCompleted ? 'Mark active' : 'Mark complete',
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final saved = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TaskFormScreen(
                                        repository: widget.repository,
                                        clock: widget.clock,
                                        task: task,
                                      ),
                                    ),
                                  );
                                  if (saved == true && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Task updated.'),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit task'),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _busy ? null : _delete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete task'),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Prototype · Completing a task updates its status; it does not add study hours. Changes reset when the app restarts.',
                          style: TextStyle(
                            color: planovaMuted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}
