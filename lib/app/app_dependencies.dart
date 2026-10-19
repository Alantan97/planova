import '../core/time/app_clock.dart';
import '../core/time/demo_clock.dart';
import '../data/mock/mock_study_repository.dart';
import '../data/mock/mock_task_repository.dart';
import '../data/repositories/study_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/local/local_task_repository.dart';
import '../data/local/open_task_database.dart';

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
  static Future<AppDependencies> local() async {
    final fixtures = MockTaskRepository();
    final seed = fixtures.tasks;
    fixtures.dispose();
    final tasks = await LocalTaskRepository.open(
      await openTaskDatabase(),
      seedTasks: seed,
    );
    return AppDependencies(
      tasks: tasks,
      study: MockStudyRepository(tasks: tasks),
      clock: const DemoClock(),
    );
  }

  Future<void> close() => tasks.close();
  final TaskRepository tasks;
  final StudyRepository study;
  final AppClock clock;
}
