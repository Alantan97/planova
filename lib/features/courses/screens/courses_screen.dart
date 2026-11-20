import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_course.dart';
import '../../tasks/screens/task_form_screen.dart';
import 'academic_record_form.dart';
import 'proforma_import_screen.dart';
import 'weekly_learning_preview_screen.dart';
import '../../../models/proforma.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({
    super.key,
    required this.repository,
    required this.clock,
  });
  final TaskRepository repository;
  final AppClock clock;
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  bool _busy = false;
  TaskRepository get _repository => widget.repository;
  void _edit({
    AcademicSemester? semester,
    AcademicCourse? course,
    String? semesterId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AcademicRecordForm(
          repository: _repository,
          clock: widget.clock,
          semester: semester,
          course: course,
          semesterId: semesterId,
        ),
      ),
    );
  }

  Future<void> _delete(String label, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $label?'),
        content: const Text(
          'Courses with tasks and semesters with courses cannot be deleted. Deleting a course also removes its saved weekly learning.',
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
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(academicSaveError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _repository,
    builder: (context, _) {
      final semesters = _repository.semesters.toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      return Scaffold(
        appBar: AppBar(title: const Text('Courses & semesters')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const PageHeading(
                    title: 'Your courses.',
                    subtitle:
                        'Keep your coursework together, semester by semester.',
                  ),
                  const SizedBox(height: 24),
                  FeaturedPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACADEMIC OVERVIEW',
                          style: TextStyle(
                            color: planovaOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_repository.courses.length} ${_repository.courses.length == 1 ? 'course' : 'courses'} · ${semesters.length} ${semesters.length == 1 ? 'semester' : 'semesters'}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          semesters.isEmpty
                              ? 'Start with the dates in your academic calendar.'
                              : 'Import a proforma or add your courses manually.',
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      const Text(
                        'Semesters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : () => _edit(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add semester'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (semesters.isEmpty)
                    const Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            color: planovaMuted,
                            size: 28,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'A place for every course.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add your first semester above, then bring in courses from your proformas or enter them yourself.',
                            style: TextStyle(color: planovaMuted, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  for (final semester in semesters) ...[
                    _semester(semester),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Existing manual tasks stay unlinked until you choose a course in Edit task. Imported drafts need your review before saving.',
                    style: TextStyle(
                      color: planovaMuted,
                      height: 1.5,
                      fontSize: 12,
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

  Widget _semester(AcademicSemester semester) {
    final courses = _repository.courses
        .where((c) => c.semesterId == semester.id)
        .toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      semester.name,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_date(semester.startDate)} – ${_date(semester.endDate)}',
                      style: const TextStyle(
                        color: planovaMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              _recordMenu(
                tooltip: 'Semester options',
                editLabel: 'Edit semester',
                deleteLabel: 'Delete semester',
                onEdit: () => _edit(semester: semester),
                onDelete: () => _delete(
                  'semester',
                  () => _repository.deleteSemester(semester.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${courses.length} ${courses.length == 1 ? 'course' : 'courses'}',
            style: const TextStyle(
              color: planovaMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (courses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No courses yet. Import a proforma to review course details and assessments, or add a course manually.',
                style: TextStyle(color: planovaMuted, height: 1.5),
              ),
            ),
          for (final course in courses) _course(course),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProformaImportScreen(
                        repository: _repository,
                        clock: widget.clock,
                        semesterId: semester.id,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.upload_file_outlined, size: 20),
            label: const Text('Import proforma'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _edit(semesterId: semester.id),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add course'),
          ),
        ],
      ),
    );
  }

  Widget _recordMenu({
    required String tooltip,
    required String editLabel,
    required String deleteLabel,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) => PopupMenuButton<String>(
    tooltip: tooltip,
    enabled: !_busy,
    icon: const Icon(Icons.more_horiz, color: planovaMuted),
    onSelected: (value) {
      if (value == 'edit') {
        onEdit();
      } else {
        onDelete();
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'edit', child: Text(editLabel)),
      PopupMenuItem(value: 'delete', child: Text(deleteLabel)),
    ],
  );

  Widget _course(AcademicCourse course) {
    final count = _repository.tasks
        .where((t) => t.courseId == course.id)
        .length;
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: planovaBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  course.code,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _recordMenu(
                tooltip: 'Course options for ${course.code}',
                editLabel: 'Edit course',
                deleteLabel: 'Delete course',
                onEdit: () => _edit(course: course),
                onDelete: () => _delete(
                  'course',
                  () => _repository.deleteCourse(course.id),
                ),
              ),
            ],
          ),
          Text(
            course.name,
            style: const TextStyle(height: 1.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                '$count linked ${count == 1 ? 'task' : 'tasks'}',
                style: const TextStyle(color: planovaMuted, fontSize: 12),
              ),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TaskFormScreen(
                            repository: _repository,
                            clock: widget.clock,
                            initialCourseId: course.id,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add task'),
              ),
              if (course.weeklyLearning.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(
                    'Weekly learning (${course.weeklyLearning.length})',
                  ),
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => WeeklyLearningPreviewScreen(
                              rows: course.weeklyLearning
                                  .map((r) => r.confirmed)
                                  .toList(),
                              description: 'Your saved, reviewed workload. Edits are saved only when you choose Save changes. Original PDF evidence is kept.',
                              onSave: (rows) => _repository.saveWeeklyLearning(
                                course.id,
                                [
                                  for (var i = 0; i < rows.length; i++)
                                    ReviewedWeeklyLearning(
                                      printed: course.weeklyLearning[i].printed,
                                      confirmed: rows[i],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _date(DateTime date) =>
      '${date.day} ${months[date.month - 1]} ${date.year}';
}
