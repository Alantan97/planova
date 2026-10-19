import '../../models/academic_course.dart';
import '../../models/academic_task.dart';
import '../../models/proforma.dart';

/// One aggregate keeps course relationships and task changes atomic.
class AcademicRecords {
  AcademicRecords({
    List<AcademicTask> tasks = const [],
    List<AcademicSemester> semesters = const [],
    List<AcademicCourse> courses = const [],
  }) : tasks = List.of(tasks),
       semesters = List.of(semesters),
       courses = List.of(courses);
  final List<AcademicTask> tasks;
  final List<AcademicSemester> semesters;
  final List<AcademicCourse> courses;

  ProformaImportResult importProforma(
    AcademicCourse proposed,
    List<AcademicTask> confirmedTasks,
  ) {
    final source = proposed.source;
    if (source == null) {
      throw const FormatException('Import source is missing.');
    }
    final previousCourse = courses
        .where(
          (c) =>
              c.semesterId == proposed.semesterId &&
              (c.source?.fingerprint == source.fingerprint ||
                  tasks.any(
                    (t) =>
                        t.courseId == c.id &&
                        t.source?.fingerprint == source.fingerprint,
                  )),
        )
        .firstOrNull;
    if (previousCourse != null &&
        previousCourse.code.toUpperCase() != proposed.code.toUpperCase()) {
      throw StateError(
        'This document is already linked to ${previousCourse.code} in this semester. Edit that course instead.',
      );
    }
    var course = courses
        .where(
          (c) =>
              c.semesterId == proposed.semesterId &&
              c.code.trim().toUpperCase() == proposed.code.trim().toUpperCase(),
        )
        .firstOrNull;
    if (course == null) {
      course = proposed;
      saveCourse(course, isNew: true);
    } else if (course.source == null) {
      course = AcademicCourse(
        id: course.id,
        semesterId: course.semesterId,
        code: course.code,
        name: course.name,
        source: source,
      );
      saveCourse(course, isNew: false);
    }
    var added = 0;
    var skipped = 0;
    for (final task in confirmedTasks) {
      final evidence = task.source;
      if (evidence == null ||
          evidence.fingerprint != source.fingerprint ||
          evidence.rowId == 'course') {
        throw const FormatException('Invalid assessment source.');
      }
      if (tasks.any(
        (t) =>
            t.courseId == course!.id &&
            t.source?.fingerprint == evidence.fingerprint &&
            t.source?.rowId == evidence.rowId,
      )) {
        skipped++;
        continue;
      }
      if (tasks.any((t) => t.id == task.id)) {
        throw StateError('A task with this ID already exists.');
      }
      tasks.add(task.copyWith(courseId: course.id, subject: course.label));
      added++;
    }
    return ProformaImportResult(
      courseId: course.id,
      addedTasks: added,
      skippedTasks: skipped,
    );
  }

  void synchronizeCourseLabels() {
    for (var i = 0; i < tasks.length; i++) {
      final course = courses
          .where((c) => c.id == tasks[i].courseId)
          .firstOrNull;
      if (course != null) tasks[i] = tasks[i].copyWith(subject: course.label);
    }
  }

  void validate() {
    void unique(Iterable<String> values, String label) {
      final list = values.toList();
      if (list.any((value) => value.trim().isEmpty) ||
          list.toSet().length != list.length) {
        throw FormatException('Invalid or duplicate $label.');
      }
    }

    unique(semesters.map((s) => s.id), 'semester ID');
    unique(semesters.map((s) => s.name.trim().toLowerCase()), 'semester name');
    unique(courses.map((c) => c.id), 'course ID');
    unique(tasks.map((t) => t.id), 'task ID');
    unique(
      courses.map((c) => '${c.semesterId}/${c.code.trim().toUpperCase()}'),
      'course code in a semester',
    );
    for (final semester in semesters) {
      if (semester.endDate.isBefore(semester.startDate)) {
        throw const FormatException(
          'Semester end must be on or after its start.',
        );
      }
    }
    for (final course in courses) {
      if (course.code.trim().isEmpty ||
          course.name.trim().isEmpty ||
          !semesters.any((s) => s.id == course.semesterId)) {
        throw const FormatException(
          'Enter a course code, name, and valid semester.',
        );
      }
    }
    for (final task in tasks) {
      if (task.title.trim().isEmpty ||
          task.subject.trim().isEmpty ||
          task.estimatedMinutes < 1 ||
          task.completedMinutes < 0 ||
          task.completedMinutes > task.estimatedMinutes) {
        throw const FormatException('Invalid task fields or effort.');
      }
      if (task.courseId != null && !courses.any((c) => c.id == task.courseId)) {
        throw const FormatException('The selected course no longer exists.');
      }
    }
  }

  void saveSemester(AcademicSemester value, {required bool isNew}) {
    final index = semesters.indexWhere((s) => s.id == value.id);
    if (isNew ? index >= 0 : index < 0) {
      throw StateError('Semester record has changed.');
    }
    if (isNew) {
      semesters.add(value);
    } else {
      semesters[index] = value;
    }
  }

  void saveCourse(AcademicCourse value, {required bool isNew}) {
    final index = courses.indexWhere((c) => c.id == value.id);
    if (isNew ? index >= 0 : index < 0) {
      throw StateError('Course record has changed.');
    }
    if (isNew) {
      courses.add(value);
    } else {
      courses[index] = value;
    }
    synchronizeCourseLabels();
  }

  void deleteCourse(String id) {
    if (tasks.any((t) => t.courseId == id)) {
      throw StateError(
        'Move or unlink this course’s tasks before deleting it.',
      );
    }
    courses.removeWhere((c) => c.id == id);
  }

  void deleteSemester(String id) {
    if (courses.any((c) => c.semesterId == id)) {
      throw StateError('Move or delete this semester’s courses first.');
    }
    semesters.removeWhere((s) => s.id == id);
  }
}
