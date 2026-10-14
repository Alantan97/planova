import '../core/time/demo_clock.dart';
import '../data/mock/mock_study_repository.dart';
import '../data/mock/mock_task_repository.dart';
import '../data/repositories/study_repository.dart';
import '../data/repositories/task_repository.dart';

/// Composition root: screens receive contracts, never backend SDK objects.
class AppDependencies {
  AppDependencies({
    required this.tasks,
    required this.study,
    required this.clock,
  });
  factory AppDependencies.demo() {
    final tasks = MockTaskRepository();
    return AppDependencies(
      tasks: tasks,
      study: MockStudyRepository(tasks: tasks),
      clock: const DemoClock(),
    );
  }
  final TaskRepository tasks;
  final StudyRepository study;
  final AppClock clock;
}
