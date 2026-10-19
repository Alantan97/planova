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
  AcademicCourse? courseById(String? id) =>
      courses.where((course) => course.id == id).firstOrNull;
  Future<void> saveSemester(AcademicSemester semester, {required bool isNew});
  Future<void> saveCourse(AcademicCourse course, {required bool isNew});
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
