import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_course.dart';
import '../../courses/screens/academic_record_form.dart';
import '../../courses/screens/proforma_import_screen.dart';
import '../../tasks/screens/task_form_screen.dart';

import 'step_intro.dart';

/// The semester's courses with import / add-course actions.
class CoursesStep extends StatelessWidget {
  const CoursesStep({super.key, required this.tasks, required this.clock});
  final TaskRepository tasks;
  final AppClock clock;

  /// Whether the current semester has at least one course.
  static bool hasCourses(TaskRepository tasks, DateTime now) {
    final semester = tasks.currentSemester(now);
    return semester != null &&
        tasks.courses.any((c) => c.semesterId == semester.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tasks,
    builder: (context, _) {
      final semester = tasks.currentSemester(clock.now());
      if (semester == null) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: const [
            StepIntro('Add your courses', 'Add your semester first.'),
          ],
        );
      }
      final courses = tasks.courses
          .where((course) => course.semesterId == semester.id)
          .toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          const StepIntro(
            'Add your courses',
            'Import each course proforma (PDF). Planova reads the assessments and their study hours for you.',
          ),
          for (final course in courses) _courseRow(context, course),
          if (courses.isNotEmpty) const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('setup-import'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProformaImportScreen(
                  repository: tasks,
                  clock: clock,
                  semesterId: semester.id,
                ),
              ),
            ),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              courses.isEmpty ? 'Import a proforma' : 'Import another proforma',
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('setup-add-course'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AcademicRecordForm(
                  repository: tasks,
                  clock: clock,
                  semesterId: semester.id,
                ),
              ),
            ),
            child: const Text('No PDF? Add a course yourself'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Missing due dates can be added in the next steps or later from Today.',
            textAlign: TextAlign.center,
            style: TextStyle(color: planovaMuted, fontSize: 13),
          ),
        ],
      );
    },
  );

  /// A course is only "done" here once it has assessments. A course added by
  /// hand starts empty, so it offers "Add assessment" instead of a tick.
  Widget _courseRow(BuildContext context, AcademicCourse course) {
    final linked = tasks.tasks.where((t) => t.courseId == course.id);
    final missing = linked
        .where((t) => !t.isCompleted && !t.hasDeadline)
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    linked.isEmpty
                        ? 'No assessments yet'
                        : '${linked.length} ${linked.length == 1 ? 'assessment' : 'assessments'}'
                              '${missing > 0 ? ' · $missing need a date' : ''}',
                    style: TextStyle(
                      color: linked.isEmpty
                          ? const Color(0xFF8F3300)
                          : planovaMuted,
                      fontSize: 13,
                      fontWeight: linked.isEmpty
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  if (linked.isNotEmpty)
                    TextButton.icon(
                      key: ValueKey('setup-more-assessment-${course.id}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => _addAssessment(context, course),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add another assessment'),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (linked.isEmpty)
              FilledButton.tonal(
                key: ValueKey('setup-add-assessment-${course.id}'),
                onPressed: () => _addAssessment(context, course),
                child: const Text('Add assessment'),
              )
            else
              Icon(
                missing > 0
                    ? Icons.event_busy_outlined
                    : Icons.check_circle_rounded,
                color: missing > 0 ? planovaMuted : planovaActionOrange,
              ),
          ],
        ),
      ),
    );
  }

  void _addAssessment(BuildContext context, AcademicCourse course) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TaskFormScreen(
            repository: tasks,
            clock: clock,
            initialCourseId: course.id,
          ),
        ),
      );
}
