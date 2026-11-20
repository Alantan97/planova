import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/data/mock/mock_study_repository.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/data/repositories/availability_repository.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/weekly_availability.dart';

import '../../support/widget_actions.dart';

/// Like the real local app on first launch: no tasks and no sample sessions.
Future<AppDependencies> emptyRealMode({bool keepTasks = false}) async {
  final tasks = MockTaskRepository();
  if (!keepTasks) {
    for (final task in tasks.tasks.toList()) {
      await tasks.delete(task.id);
    }
  }
  return AppDependencies(
    tasks: tasks,
    study: MockStudyRepository(tasks: tasks, includeSamples: false),
    clock: const DemoClock(),
    availability: MemoryAvailabilityRepository(),
  );
}

void main() {
  testWidgets('First run shows setup steps and honest empty states', (
    tester,
  ) async {
    final dependencies = await emptyRealMode();
    addTearDown(dependencies.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.text('GET STARTED · 0 OF 3 DONE'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.textContaining('caught up'), findsNothing);
    expect(find.text('Sample study week'), findsNothing);
    expect(find.textContaining('No study sessions yet'), findsOneWidget);
    expect(find.textContaining('are samples'), findsNothing);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('No study plan yet'), findsOneWidget);
    expect(find.text('No study sessions on this day.'), findsOneWidget);
    expect(find.textContaining('sample'), findsNothing);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Study time is not tracked yet'), findsOneWidget);
    expect(find.text('0 of 0 tasks completed'), findsOneWidget);
    expect(find.textContaining('sample'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Setup steps tick off from saved data, then the card hides', (
    tester,
  ) async {
    final dependencies = await emptyRealMode();
    addTearDown(dependencies.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    await dependencies.tasks.saveSemester(
      AcademicSemester(
        id: 's1',
        name: 'Semester 1',
        startDate: DateTime(2026, 10),
        endDate: DateTime(2027, 2),
      ),
      isNew: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('GET STARTED · 1 OF 3 DONE'), findsOneWidget);

    await dependencies.tasks.saveCourse(
      const AcademicCourse(
        id: 'c1',
        semesterId: 's1',
        code: 'DES3113',
        name: 'Mobile',
      ),
      isNew: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('GET STARTED · 2 OF 3 DONE'), findsOneWidget);

    // The remaining step opens the availability screen.
    await tapVisible(tester, find.byKey(const ValueKey('setup-availability')));
    expect(find.text('Your normal week.'), findsOneWidget);
    await dependencies.availability.saveWindow(
      StudyWindow(
        id: 'w1',
        range: WeeklyTimeRange(
          weekdays: [1],
          startMinute: 20 * 60,
          endMinute: 22 * 60,
        ),
      ),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('GET STARTED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No-tasks panel opens courses; completed tasks say caught up', (
    tester,
  ) async {
    final empty = await emptyRealMode();
    addTearDown(empty.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: empty));
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('today-import-proforma')),
    );
    expect(find.text('Your courses.'), findsOneWidget);

    final done = await emptyRealMode(keepTasks: true);
    addTearDown(done.tasks.dispose);
    for (final task in done.tasks.tasks.toList()) {
      await done.tasks.setCompleted(task.id, true);
    }
    await tester.pumpWidget(MyApp(key: UniqueKey(), dependencies: done));
    await tester.pumpAndSettle();
    expect(
      find.text('You are all caught up. Every saved task is complete.'),
      findsOneWidget,
    );
    expect(find.text('No tasks yet'), findsNothing);
  });

  testWidgets('Setup card fits a small phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final dependencies = await emptyRealMode();
    addTearDown(dependencies.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final tab in ['Plan', 'Progress']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
