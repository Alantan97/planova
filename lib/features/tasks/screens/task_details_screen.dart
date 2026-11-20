import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_task.dart';
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

  Future<void> _edit(AcademicTask task) async {
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
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task updated.')));
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
          actions: [
            if (task != null)
              PopupMenuButton<String>(
                tooltip: 'Task options',
                enabled: !_busy,
                icon: const Icon(Icons.more_horiz),
                onSelected: (_) => _delete(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete task'),
                  ),
                ],
              ),
          ],
        ),
        bottomNavigationBar: task == null
            ? null
            : SafeArea(
                top: false,
                child: Align(
                  heightFactor: 1,
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                      child: _actions(task),
                    ),
                  ),
                ),
              ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: task == null
                  ? _removedTask()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ListView(
                            key: PageStorageKey(
                              'task-detail-scroll-${task.id}',
                            ),
                            padding: const EdgeInsets.all(24),
                            children: [
                              const Eyebrow('ACADEMIC TASK'),
                              const SizedBox(height: 12),
                              Text(
                                task.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                task.subject,
                                style: const TextStyle(
                                  color: planovaMuted,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _progress(task),
                              const SizedBox(height: 20),
                              Panel(
                                child: _detail(
                                  Icons.event_outlined,
                                  'Deadline',
                                  '${task.deadline.day} ${months[task.deadline.month - 1]} ${task.deadline.year}',
                                  secondary: TimeOfDay.fromDateTime(
                                    task.deadline,
                                  ).format(context),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Panel(
                                child: Column(
                                  children: [
                                    _detail(
                                      Icons.tune_rounded,
                                      'Difficulty',
                                      _capitalized(task.difficulty.name),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Divider(
                                        height: 1,
                                        color: planovaBorder,
                                      ),
                                    ),
                                    _detail(
                                      Icons.flag_outlined,
                                      'Importance',
                                      _capitalized(task.importance.name),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Divider(
                                        height: 1,
                                        color: planovaBorder,
                                      ),
                                    ),
                                    _detail(
                                      Icons.percent_rounded,
                                      'Assessment weight',
                                      task.assessmentWeightPercent == null
                                          ? 'Not confirmed'
                                          : '${task.assessmentWeightPercent}% of course grade',
                                      secondary:
                                          task.assessmentWeightPercent == null
                                          ? 'Add it in Edit task to use experimental ranking.'
                                          : 'Confirmed by you.',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (task.description.trim().isNotEmpty)
                                ExpansionTile(
                                  key: PageStorageKey('task-notes-${task.id}'),
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Notes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: SelectableText(
                                          task.description,
                                          key: PageStorageKey(
                                            'task-notes-text-${task.id}',
                                          ),
                                          style: const TextStyle(height: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const Text(
                                  'No notes yet. Add them in Edit task.',
                                  style: TextStyle(
                                    color: planovaMuted,
                                    height: 1.5,
                                  ),
                                ),
                              if (task.source != null) ...[
                                const SizedBox(height: 12),
                                ExpansionTile(
                                  key: PageStorageKey('task-source-${task.id}'),
                                  tilePadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Proforma source',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'PDF page ${task.source!.page}',
                                    style: const TextStyle(
                                      color: planovaMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: SelectableText(
                                          key: PageStorageKey(
                                            'task-source-text-${task.id}',
                                          ),
                                          '${task.source!.fileName} · ${task.source!.rowId}${task.source!.assessmentWeight == null ? '' : '\nDocument assessment weight: ${task.source!.assessmentWeight}% (separate from task importance)'}\n\n${task.source!.excerpt}',
                                          style: const TextStyle(
                                            color: planovaMuted,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              const Text(
                                'Tasks are saved locally on this device.',
                                style: TextStyle(
                                  color: planovaMuted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
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

  Widget _progress(AcademicTask task) {
    final overdue =
        !task.isCompleted && task.deadline.isBefore(widget.clock.now());
    final remaining = (task.estimatedMinutes - task.completedMinutes).clamp(
      0,
      task.estimatedMinutes,
    );
    final status = task.isCompleted
        ? 'COMPLETED'
        : overdue
        ? 'OVERDUE'
        : task.completedMinutes > 0
        ? 'IN PROGRESS'
        : 'NOT STARTED';
    return FeaturedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: const TextStyle(
              color: planovaOrange,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            task.isCompleted
                ? 'Task completed'
                : '${formatDuration(remaining)} remaining',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: task.progress,
              minHeight: 6,
              color: planovaOrange,
              backgroundColor: Colors.white24,
              semanticsLabel: 'Task progress',
              semanticsValue: '${(task.progress * 100).round()}%',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            task.isCompleted
                ? 'Marked complete'
                : '${(task.progress * 100).round()}% of estimated time recorded',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatDuration(task.completedMinutes)} recorded · ${formatDuration(task.estimatedMinutes)} total estimate',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Marking complete does not add study time.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _detail(
    IconData icon,
    String label,
    String value, {
    String? secondary,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: planovaMuted, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: planovaMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            if (secondary != null)
              Text(
                secondary,
                style: const TextStyle(color: planovaMuted, height: 1.5),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _actions(AcademicTask task) {
    final complete = FilledButton.icon(
      onPressed: _busy ? null : () => _complete(!task.isCompleted),
      icon: Icon(task.isCompleted ? Icons.undo_rounded : Icons.check_rounded),
      label: Text(
        _busy
            ? 'Saving…'
            : task.isCompleted
            ? 'Mark active'
            : 'Mark complete',
      ),
    );
    final edit = OutlinedButton.icon(
      onPressed: _busy ? null : () => _edit(task),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit task'),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 400
          ? Row(
              children: [
                Expanded(child: edit),
                const SizedBox(width: 12),
                Expanded(child: complete),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [complete, const SizedBox(height: 8), edit],
            ),
    );
  }

  Widget _removedTask() => Padding(
    padding: const EdgeInsets.all(24),
    child: Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.task_alt_rounded, color: planovaMuted, size: 32),
          const SizedBox(height: 16),
          const Text(
            'This task has been removed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Go back'),
          ),
        ],
      ),
    ),
  );

  String _capitalized(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
