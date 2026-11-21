import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/time/app_clock.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/data/repositories/availability_repository.dart';
import 'package:planova/data/repositories/profile_repository.dart';
import 'package:planova/data/repositories/study_plan_repository.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/onboarding_progress.dart';
import 'package:planova/models/weekly_availability.dart';

import '../../support/widget_actions.dart';

/// A non-preview clock pinned to the same moment, to check the real-app UI.
class _FixedClock implements AppClock {
  const _FixedClock();
  @override
  DateTime now() => DateTime(2026, 10, 14, 13);
}

Future<AppDependencies> student({
  int step = 0,
  bool completed = false,
  AppClock clock = const DemoClock(),
  bool withCourse = false,
}) async {
  final tasks = MockTaskRepository();
  for (final t in tasks.tasks.toList()) {
    await tasks.delete(t.id);
  }
  if (withCourse) {
    await tasks.saveSemester(
      AcademicSemester(
        id: 's1',
        name: 'Semester 1',
        startDate: DateTime(2026, 10),
        endDate: DateTime(2027, 2),
      ),
      isNew: true,
    );
    await tasks.saveCourse(
      const AcademicCourse(
        id: 'c1',
        semesterId: 's1',
        code: 'DES3113',
        name: 'Mobile',
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
    clock: clock,
    availability: availability,
    plans: plans,
    profile: MemoryProfileRepository(
      OnboardingProgress(
        step: step,
        completed: completed,
        accountType: AccountType.guest,
      ),
    ),
  );
}

void main() {
  test('The real app uses the device clock', () {
    final before = DateTime.now();
    final now = const SystemClock().now();
    expect(now.isBefore(before), isFalse);
    expect(now.difference(before).inSeconds, lessThan(5));
  });

  testWidgets('"Preview date" shows only with the fixed demo clock', (
    tester,
  ) async {
    final demo = await student(completed: true);
    addTearDown(demo.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: demo));
    await tester.pumpAndSettle();
    expect(find.text('Preview date'), findsOneWidget);

    final real = await student(completed: true, clock: const _FixedClock());
    addTearDown(real.tasks.dispose);
    await tester.pumpWidget(MyApp(key: UniqueKey(), dependencies: real));
    await tester.pumpAndSettle();
    expect(find.text('Preview date'), findsNothing);
  });

  testWidgets('A course added by hand asks for assessments, not a tick', (
    tester,
  ) async {
    final d = await student(step: 4, withCourse: true);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(find.text('STEP 3 OF 7 · COURSES'), findsOneWidget);
    expect(find.text('No assessments yet'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('setup-add-assessment-c1')),
    );
    expect(find.text('Add task'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'Assignment 1',
    );
    tester.testTextInput.hide();
    await tapVisible(tester, find.text('Save task'));
    expect(d.tasks.tasks.single.courseId, 'c1');
    expect(find.text('1 assessment'), findsOneWidget);
    expect(find.text('Add another assessment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty due-date and plan steps link back to the fix', (
    tester,
  ) async {
    final d = await student(step: 6, withCourse: true);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();

    // No assessments: the due-date step says so and links to Courses.
    expect(
      find.textContaining('Every assessment has a due date'),
      findsNothing,
    );
    expect(
      find.text(
        'You have no assessments yet, so there are no due dates to add.',
      ),
      findsOneWidget,
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('onboarding-fix-dates')),
    );
    expect(find.text('STEP 3 OF 7 · COURSES'), findsOneWidget);

    // A dated assessment but no study times: the plan step points to the week.
    await d.tasks.add(
      AcademicTask(
        id: 'quiz',
        title: 'Quiz 1',
        subject: 'DES3113 · Mobile',
        description: '',
        deadline: DateTime(2026, 10, 16, 23, 59),
        estimatedMinutes: 60,
        courseId: 'c1',
      ),
    );
    // Leave and re-enter the journey at step 7 (as "Finish later" + resume).
    await d.profile.save(d.profile.progress.copyWith(completed: true));
    await tester.pumpAndSettle();
    await d.profile.save(
      d.profile.progress.copyWith(completed: false, step: 7),
    );
    await tester.pumpAndSettle();
    expect(find.text('STEP 6 OF 7 · FIRST PLAN'), findsOneWidget);
    expect(
      find.text('Planova needs to know when you can study.'),
      findsOneWidget,
    );
    await tapVisible(tester, find.byKey(const ValueKey('onboarding-fix-plan')));
    expect(find.text('STEP 4 OF 7 · YOUR WEEK'), findsOneWidget);

    // With study times, the plan step offers the plan instead.
    await tapVisible(
      tester,
      find.byKey(const ValueKey('preset-weekday-evenings')),
    );
    await tapVisible(tester, find.byKey(const ValueKey('onboarding-next')));
    await tapVisible(tester, find.byKey(const ValueKey('onboarding-next')));
    expect(find.text('1 session · 1h · 1 task'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-fix-plan')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create my plan is in the top panel until a plan exists', (
    tester,
  ) async {
    final d = await student(completed: true, withCourse: true);
    addTearDown(d.tasks.dispose);
    await d.tasks.add(
      AcademicTask(
        id: 'quiz',
        title: 'Quiz 1',
        subject: 'DES3113 · Mobile',
        description: '',
        deadline: DateTime(2026, 10, 16, 23, 59),
        estimatedMinutes: 60,
        courseId: 'c1',
      ),
    );
    await d.availability.saveWindow(
      StudyWindow(
        id: 'w',
        range: WeeklyTimeRange(
          weekdays: [3],
          startMinute: 20 * 60,
          endMinute: 22 * 60,
        ),
      ),
    );
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('create-plan'));
    expect(button, findsOneWidget);
    expect(find.text('Create my plan'), findsOneWidget);
    // Visible without scrolling, above the bottom navigation.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getBottomLeft(button).dy, lessThan(screen.height - 100));
    expect(find.text('Plan the next 7 days'), findsNothing);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('proposal-accept')));
    expect(find.text('Create my plan'), findsNothing);
    expect(find.byKey(const ValueKey('create-plan')), findsOneWidget);
    expect(find.text('Re-plan the next 7 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
