import 'package:planova/app/app_dependencies.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/data/repositories/availability_repository.dart';
import 'package:planova/data/repositories/profile_repository.dart';
import 'package:planova/data/repositories/study_plan_repository.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/onboarding_progress.dart';

/// A "real mode" app for widget tests: no sample tasks or sessions, the fixed
/// preview clock (Wed 14 Oct 2026, 13:00), in-memory storage and planning.
///
/// [semesters] semesters (`s1`, `s2`, …) are created, and [courses] courses
/// (`c1`, `c2`, …, codes `DES3111`, `DES3112`, …) in the first semester.
/// Without [progress] the guided journey counts as finished.
Future<AppDependencies> realModeApp({
  int semesters = 1,
  int courses = 0,
  OnboardingProgress? progress,
}) async {
  final tasks = MockTaskRepository();
  for (final t in tasks.tasks.toList()) {
    await tasks.delete(t.id);
  }
  for (var i = 1; i <= semesters; i++) {
    await tasks.saveSemester(
      AcademicSemester(
        id: 's$i',
        name: 'Semester $i',
        startDate: DateTime(2026, 10),
        endDate: DateTime(2027, 2),
      ),
      isNew: true,
    );
  }
  for (var i = 1; i <= courses; i++) {
    await tasks.saveCourse(
      AcademicCourse(
        id: 'c$i',
        semesterId: 's1',
        code: 'DES311$i',
        name: 'Course $i',
      ),
      isNew: true,
    );
  }
  final availability = MemoryAvailabilityRepository();
  final plans = MemoryStudyPlanRepository(
    tasks: tasks,
    availability: availability,
  );
  return AppDependencies(
    tasks: tasks,
    study: plans,
    clock: const DemoClock(),
    availability: availability,
    plans: plans,
    profile: MemoryProfileRepository(progress),
  );
}
