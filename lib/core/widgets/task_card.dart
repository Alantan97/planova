import 'package:flutter/material.dart';

import '../../models/academic_task.dart';
import '../theme/app_theme.dart';
import '../time/date_time_helpers.dart';

/// "Today · 13:00", "Tomorrow", "21 October" or "No due date yet".
/// Shared by task cards and the compact rows on the Courses tab.
String dueDateLabel(BuildContext context, AcademicTask task, DateTime now) {
  final deadline = task.deadline;
  if (deadline == null) return 'No due date yet';
  if (DateUtils.isSameDay(deadline, now)) {
    return 'Today · ${TimeOfDay.fromDateTime(deadline).format(context)}';
  }
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (DateUtils.isSameDay(deadline, tomorrow)) return 'Tomorrow';
  return '${deadline.day} ${months[deadline.month - 1]}${deadline.year != now.year ? ' ${deadline.year}' : ''}';
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.now,
    required this.onTap,
  });
  final AcademicTask task;
  final DateTime now;
  final VoidCallback onTap;

  String _deadline(BuildContext context) => dueDateLabel(context, task, now);

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdueAt(now);
    final statusColor = overdue ? planovaActionOrange : planovaMuted;
    final remaining = (task.estimatedMinutes - task.completedMinutes).clamp(
      0,
      task.estimatedMinutes,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: planovaBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            height: 1.3,
                            color: task.isCompleted ? planovaMuted : planovaInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: planovaMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    task.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: planovaMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _TaskMeta(
                        icon: task.isCompleted
                            ? Icons.check_circle_outline_rounded
                            : overdue
                            ? Icons.error_outline_rounded
                            : Icons.event_outlined,
                        text: task.isCompleted
                            ? 'Completed'
                            : '${overdue ? 'Overdue' : 'Due'} · ${_deadline(context)}',
                        color: statusColor,
                      ),
                      if (!task.isCompleted)
                        _TaskMeta(
                          icon: Icons.schedule_outlined,
                          text: '${formatDuration(remaining)} remaining',
                        ),
                    ],
                  ),
                  if (!task.isCompleted && task.completedMinutes > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: ExcludeSemantics(
                        child: LinearProgressIndicator(
                          value: task.progress,
                          minHeight: 4,
                          color: planovaOrange,
                          backgroundColor: planovaBorder,
                          semanticsLabel: '${task.title} progress',
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatDuration(task.completedMinutes)} recorded · ${(task.progress * 100).round()}% of estimate',
                      style: const TextStyle(color: planovaMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskMeta extends StatelessWidget {
  const _TaskMeta({
    required this.icon,
    required this.text,
    this.color = planovaMuted,
  });
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
