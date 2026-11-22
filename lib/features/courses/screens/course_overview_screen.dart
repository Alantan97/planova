import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../core/widgets/task_card.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_course.dart';
import '../../../models/academic_task.dart';
import '../../../services/ranking/task_ranking_service.dart';
import '../../ranking/screens/task_ranking_screen.dart';
import '../../tasks/screens/task_details_screen.dart';
import '../../tasks/screens/task_form_screen.dart';
import '../start_proforma_import.dart';
import 'courses_screen.dart';

/// One group on the Courses tab: a saved course, or a subject typed by hand
/// for tasks that are not linked to a course.
class _Group {
  _Group(this.title, this.tasks, {this.course});
  final String title;
  final List<AcademicTask> tasks;
  final AcademicCourse? course;
  int get done => tasks.where((task) => task.isCompleted).length;
}

/// The Courses tab: every task grouped under its course, the way proformas
/// and students organise work. Replaces the flat Tasks list.
class CourseOverviewScreen extends StatelessWidget {
  const CourseOverviewScreen({
    super.key,
    required this.repository,
    required this.clock,
    required this.ranking,
  });
  final TaskRepository repository;
  final AppClock clock;
  final TaskRankingService ranking;

  /// Current semester's courses first (by code), then other courses, then
  /// unlinked tasks grouped by their typed subject. Tasks inside a group:
  /// active by due date (undated last), then completed.
  List<_Group> _groups() {
    final current = repository.currentSemester(clock.now());
    final courses = [...repository.courses]
      ..sort((a, b) {
        final aCurrent = a.semesterId == current?.id ? 0 : 1;
        final bCurrent = b.semesterId == current?.id ? 0 : 1;
        return aCurrent != bCurrent
            ? aCurrent - bCurrent
            : a.code.compareTo(b.code);
      });
    List<AcademicTask> ordered(Iterable<AcademicTask> tasks) => [
      ...tasks.where((t) => !t.isCompleted).toList()
        ..sort(AcademicTask.byDeadline),
      ...tasks.where((t) => t.isCompleted),
    ];
    final courseIds = courses.map((c) => c.id).toSet();
    final unlinked = <String, List<AcademicTask>>{};
    for (final task in repository.tasks) {
      if (task.courseId == null || !courseIds.contains(task.courseId)) {
        unlinked.putIfAbsent(task.subject, () => []).add(task);
      }
    }
    return [
      for (final course in courses)
        _Group(
          course.label,
          ordered(repository.tasks.where((t) => t.courseId == course.id)),
          course: course,
        ),
      for (final entry
          in (unlinked.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key))))
        _Group(entry.key, ordered(entry.value)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final semester = repository.currentSemester(clock.now());
    final groups = _groups();
    final tasks = repository.tasks;
    final active = tasks.where((task) => !task.isCompleted).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          subtitle: [
            if (semester != null) semester.name,
            '$active active · ${tasks.length - active} completed',
          ].join(' · '),
          action: FilledButton.icon(
            onPressed: () => _addTask(context),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add task'),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('tasks-import-proforma'),
              onPressed: () => startProformaImport(context, repository, clock),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import proforma'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('open-task-ranking'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TaskRankingScreen(
                    repository: repository,
                    clock: clock,
                    service: ranking,
                  ),
                ),
              ),
              icon: const Icon(Icons.sort_rounded),
              label: const Text('Prioritize · experimental'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (groups.isEmpty)
          const Panel(
            child: Text(
              'A fresh start. Import a course proforma to bring in its assessments, or add a task yourself.',
              style: TextStyle(height: 1.5),
            ),
          ),
        for (final group in groups)
          _GroupCard(
            group: group,
            now: clock.now(),
            onOpen: (task) =>
                openTaskDetails(context, repository, clock, task.id),
            onAdd: group.course == null
                ? null
                : () => _addTask(context, courseId: group.course!.id),
          ),
        const SizedBox(height: 8),
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
                  Icon(Icons.tune_rounded, color: planovaInk),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Courses & semesters',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Edit courses, semester dates and weekly learning',
                          style: TextStyle(color: planovaMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: planovaMuted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Saved on this device.',
          style: TextStyle(color: planovaMuted, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _addTask(BuildContext context, {String? courseId}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          repository: repository,
          clock: clock,
          initialCourseId: courseId,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task added.')));
    }
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.now,
    required this.onOpen,
    required this.onAdd,
  });
  final _Group group;
  final DateTime now;
  final void Function(AcademicTask) onOpen;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final total = group.tasks.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: planovaBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        group.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        total == 0
                            ? 'No tasks yet'
                            : '${group.done} of $total done',
                        style: const TextStyle(
                          color: planovaMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 10),
                    // The "x of y done" text already says this aloud.
                    ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: group.done / total,
                          minHeight: 6,
                          color: planovaActionOrange,
                          backgroundColor: const Color(0xFFECEDEF),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            for (final task in group.tasks)
              _TaskRow(task: task, now: now, onTap: () => onOpen(task)),
            if (onAdd != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add task to this course'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.now, required this.onTap});
  final AcademicTask task;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdueAt(now);
    final remaining = task.estimatedMinutes - task.completedMinutes;
    final String status;
    final Color statusColor;
    if (task.isCompleted) {
      status = 'Completed';
      statusColor = planovaMuted;
    } else if (!task.hasDeadline) {
      status = 'Needs a due date · ${formatDuration(remaining)} of work';
      statusColor = const Color(0xFF8F3300);
    } else {
      status =
          '${overdue ? 'Overdue' : 'Due'} · ${dueDateLabel(context, task, now)} · ${formatDuration(remaining)} left';
      statusColor = overdue ? planovaActionOrange : planovaMuted;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFECEDEF))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                task.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: task.isCompleted ? planovaActionOrange : planovaMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: task.isCompleted ? planovaMuted : planovaInk,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: task.hasDeadline || task.isCompleted
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ],
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
        ),
      ),
    );
  }
}
