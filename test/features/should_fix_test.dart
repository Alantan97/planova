import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/core/widgets/effort_field.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/data/repositories/availability_repository.dart';
import 'package:planova/data/repositories/profile_repository.dart';
import 'package:planova/data/repositories/study_plan_repository.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/onboarding_progress.dart';
import 'package:planova/models/study_session.dart';

import '../support/widget_actions.dart';

/// Real-mode app on the preview date (Wed 14 Oct 2026, 13:00).
Future<AppDependencies> app({
  int courses = 1,
  OnboardingProgress? progress,
}) async {
  final tasks = MockTaskRepository();
  for (final t in tasks.tasks.toList()) {
    await tasks.delete(t.id);
  }
  await tasks.saveSemester(
    AcademicSemester(
      id: 's1',
      name: 'Semester 1',
      startDate: DateTime(2026, 10),
      endDate: DateTime(2027, 2),
    ),
    isNew: true,
  );
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

void main() {
  testWidgets('Today shows the next session once, not three times', (
    tester,
  ) async {
    final d = await app();
    addTearDown(d.tasks.dispose);
    await d.tasks.add(
      AcademicTask(
        id: 'quiz',
        title: 'Quiz 1',
        subject: 'DES3111 · Course 1',
        description: '',
        deadline: DateTime(2026, 10, 16, 23, 59),
        estimatedMinutes: 60,
        courseId: 'c1',
      ),
    );
    await d.plans!.acceptPlan(
      [
        StudySession(
          id: 'pm',
          taskId: 'quiz',
          title: 'Quiz 1',
          subject: 'DES3111 · Course 1',
          startsAt: DateTime(2026, 10, 14, 20),
          minutes: 60,
        ),
      ],
      from: DateTime(2026, 10, 14),
      to: DateTime(2026, 10, 21),
    );
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(find.text('Next study session · rule-based plan'), findsOneWidget);
    expect(find.text('Next deadline'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('1 study session · 1h planned'), findsOneWidget);
    expect(find.textContaining('tap to record'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip looks secondary; Continue stays the main button', (
    tester,
  ) async {
    final d = await app(
      progress: const OnboardingProgress(
        step: 2,
        accountType: AccountType.guest,
      ),
    );
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('onboarding-next'));
    expect(tester.widget(next), isA<OutlinedButton>());
    expect(find.text('Skip'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-name')),
      'Sam',
    );
    await tester.pump();
    expect(tester.widget(next), isA<FilledButton>());
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('New task defaults to the only course; date can be removed', (
    tester,
  ) async {
    final d = await app();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('today-add-task')));
    expect(find.textContaining('DES3111 · Course 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-subject')), findsNothing);
    expect(find.text('Remove due date'), findsOneWidget);
    expect(find.text('No due date yet'), findsNothing);
  });

  testWidgets('With several courses the student chooses', (tester) async {
    final d = await app(courses: 2);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('today-add-task')));
    expect(find.byKey(const ValueKey('task-subject')), findsOneWidget);
  });

  testWidgets('The matching quick effort choice is shown as selected', (
    tester,
  ) async {
    final controller = TextEditingController(text: '60');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EffortField(
            controller: controller,
            fieldKey: 'e',
            label: 'Effort',
            validate: validateEffort,
          ),
        ),
      ),
    );
    bool selected(int minutes) => tester
        .widget<ChoiceChip>(find.byKey(ValueKey('e-quick-$minutes')))
        .selected;
    expect(selected(60), isTrue);
    expect(selected(120), isFalse);
    await tester.tap(find.byKey(const ValueKey('e-quick-120')));
    await tester.pump();
    expect(selected(120), isTrue);
    expect(selected(60), isFalse);
  });

  testWidgets('All seven days fit on a 375 px phone, each 48 px wide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = await app();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      final rect = tester.getRect(find.byKey(ValueKey('day-$i')));
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(375));
    }
    await tester.tap(find.byKey(const ValueKey('day-6')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sun, 18 October'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
