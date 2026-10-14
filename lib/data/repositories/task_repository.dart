import 'package:flutter/foundation.dart';

import '../../models/academic_task.dart';

abstract class TaskRepository extends ChangeNotifier {
  List<AcademicTask> get tasks;
  AcademicTask? taskById(String id) =>
      tasks.where((task) => task.id == id).firstOrNull;
  Future<void> add(AcademicTask task);
  Future<void> update(AcademicTask task);
  Future<void> delete(String id);
  Future<void> setCompleted(String id, bool completed);
}
