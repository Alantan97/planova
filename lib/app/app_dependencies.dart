import '../core/time/app_clock.dart';
import '../core/time/demo_clock.dart';
import '../data/mock/mock_study_repository.dart';
import '../data/mock/mock_task_repository.dart';
import '../data/local/local_availability_repository.dart';
import '../data/repositories/availability_repository.dart';
import '../data/local/local_study_plan_repository.dart';
import '../data/repositories/study_plan_repository.dart';
import '../data/repositories/study_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/local/local_task_repository.dart';
import '../data/local/open_task_database.dart';
import '../services/ranking/task_ranking_service.dart';

/// Composition root: screens receive contracts, never backend SDK objects.
class AppDependencies {
  AppDependencies({
    required this.tasks,
    required this.study,
    required this.clock,
    TaskRankingService? ranking,
    AvailabilityRepository? availability,
    this.plans,
  }) : ranking = ranking ?? LocalTaskRankingService(),
       availability = availability ?? MemoryAvailabilityRepository();
  factory AppDependencies.demo() {
    final tasks = MockTaskRepository();
    return AppDependencies(
      tasks: tasks,
      study: MockStudyRepository(tasks: tasks),
      clock: const DemoClock(),
    );
  }
  static Future<AppDependencies> local() async {
    final database = await openTaskDatabase();
    final tasks = await LocalTaskRepository.open(database);
    final LocalAvailabilityRepository availability;
    final LocalStudyPlanRepository plans;
    try {
      availability = await LocalAvailabilityRepository.open(database);
      plans = await LocalStudyPlanRepository.open(
        database,
        tasks: tasks,
        availability: availability,
      );
    } catch (_) {
      await tasks.close(); // Also closes the shared database file.
      rethrow;
    }
    return AppDependencies(
      tasks: tasks,
      study: plans,
      clock: const DemoClock(),
      availability: availability,
      plans: plans,
    );
  }

  /// Plans and availability first: they share the database [tasks] closes.
  Future<void> close() async {
    await plans?.close();
    await availability.close();
    await tasks.close();
  }

  /// The accepted rule-based plan. Null in the demo build, which shows
  /// labelled sample sessions instead and cannot create plans.
  final StudyPlanRepository? plans;

  final TaskRepository tasks;
  final AvailabilityRepository availability;
  final StudyRepository study;
  final AppClock clock;
  final TaskRankingService ranking;
}
