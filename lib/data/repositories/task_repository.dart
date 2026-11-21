import 'package:flutter/foundation.dart';

import '../../models/academic_task.dart';
import '../../models/academic_course.dart';
import '../../models/proforma.dart';

abstract class TaskRepository extends ChangeNotifier {
  List<AcademicTask> get tasks;
  List<AcademicSemester> get semesters;
  List<AcademicCourse> get courses;
  Future<ProformaImportResult> importProforma(
    AcademicCourse course,
    List<AcademicTask> tasks,
  );

  /// The semester Planova sets up and imports into: the one containing
  /// [now], otherwise the one that started most recently.
  AcademicSemester? currentSemester(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final sorted = [...semesters]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return sorted
            .where((s) => !day.isBefore(s.startDate) && !day.isAfter(s.endDate))
            .firstOrNull ??
        sorted.firstOrNull;
  }

  AcademicCourse? courseById(String? id) =>
      courses.where((course) => course.id == id).firstOrNull;
  Future<void> saveSemester(AcademicSemester semester, {required bool isNew});
  Future<void> saveCourse(AcademicCourse course, {required bool isNew});
  Future<void> saveWeeklyLearning(
    String courseId,
    List<ReviewedWeeklyLearning> rows,
  );
  Future<void> deleteSemester(String id);
  Future<void> deleteCourse(String id);
  AcademicTask? taskById(String id) =>
      tasks.where((task) => task.id == id).firstOrNull;
  Future<void> add(AcademicTask task);
  Future<void> update(AcademicTask task);
  Future<void> delete(String id);
  Future<void> setCompleted(String id, bool completed);
  Future<void> close() async => dispose();
}
