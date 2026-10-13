import '../../models/academic_task.dart';

abstract interface class TaskRepository {
  List<AcademicTask> get tasks;
}
