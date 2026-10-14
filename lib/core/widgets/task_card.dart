import 'package:flutter/material.dart';

import '../../models/academic_task.dart';
import '../theme/app_theme.dart';
import '../time/demo_clock.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});
  final AcademicTask task;
  final VoidCallback onTap;

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
        onTap: onTap,
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
