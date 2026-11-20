import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/features/today/view_models/today_view_model.dart';
import 'package:planova/models/study_session.dart';
import 'package:planova/data/mock/mock_study_repository.dart';

void main() {
  test(
    'Normal local study mode contains no invented sessions or study history',
    () {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      final study = MockStudyRepository(
        tasks: dependencies.tasks,
        includeSamples: false,
      );
      for (var day = 12; day <= 25; day++) {
        expect(study.sessionsOn(DateTime(2026, 10, day)), isEmpty);
        expect(study.completedMinutesInWeek(DateTime(2026, 10, day)), 0);
      }
    },
  );
  test('Session task links and completed effort agree with task fixtures', () {
    final dependencies = AppDependencies.demo();
    final tasks = {for (final task in dependencies.tasks.tasks) task.id: task};
    final completed = <String, int>{};
    for (var day = 12; day <= 18; day++) {
      for (final session in dependencies.study.sessionsOn(
        DateTime(2026, 10, day),
      )) {
        if (session.commitment) {
          expect(session.taskId, isNull);
          continue;
        }
        expect(tasks.containsKey(session.taskId), isTrue);
        if (session.status == SessionStatus.completed) {
          completed.update(
            session.taskId!,
            (minutes) => minutes + session.minutes,
            ifAbsent: () => session.minutes,
          );
        }
      }
    }
    for (final task in tasks.values) {
      expect(completed[task.id] ?? 0, task.completedMinutes);
    }
    expect(
      dependencies.study.completedMinutesInWeek(DateTime(2026, 10, 14)),
      210,
    );
    expect(
      dependencies.study.completedMinutesInWeek(DateTime(2026, 10, 19)),
      0,
    );
  });

  test('Today excludes fixed commitments from planned study totals', () {
    final dependencies = AppDependencies.demo();
    final today = TodayViewModel(
      studyRepository: dependencies.study,
      taskRepository: dependencies.tasks,
      clock: dependencies.clock,
    );
    expect(today.workloadLabel, '2 study sessions · 1h 45m planned');
    expect(today.nextSession?.title, 'Get comfortable with graphs');
    expect(today.upcomingTask?.id, 'database');
  });
}
