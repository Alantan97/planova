import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/theme/app_theme.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/core/widgets/near_limit_counter.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/data/repositories/availability_repository.dart';
import 'package:planova/data/repositories/profile_repository.dart';
import 'package:planova/data/repositories/study_plan_repository.dart';
import 'package:planova/features/courses/screens/academic_record_form.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/onboarding_progress.dart';
import 'package:planova/models/study_session.dart';

import '../support/widget_actions.dart';

Future<AppDependencies> app({
  int semesters = 1,
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
  testWidgets('Character counters appear only near the limit', (tester) async {
    final d = await app(
      progress: const OnboardingProgress(
        step: 2,
        accountType: AccountType.guest,
      ),
    );
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('onboarding-name'));
    await tester.enterText(field, 'Sam');
    await tester.pump();
    expect(find.text('3/40'), findsNothing);
    await tester.enterText(field, 'A' * 33);
    await tester.pump();
    expect(find.text('33/40'), findsOneWidget);
    expect(
      nearLimitCounter(
        tester.element(field),
        currentLength: 5,
        isFocused: true,
        maxLength: 100,
      ),
      isNull,
    );
  });

  testWidgets('Adding a course skips the semester picker with one semester', (
    tester,
  ) async {
    final one = await app();
    addTearDown(one.tasks.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPlanovaTheme(),
        home: AcademicRecordForm(
          repository: one.tasks,
          clock: one.clock,
          semesterId: 's1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('course-semester')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('course-code')),
      'des3113',
    );
    await tester.enterText(
      find.byKey(const ValueKey('academic-name')),
      'Mobile',
    );
    await tapVisible(tester, find.text('Save course'));
    expect(one.tasks.courses.single.semesterId, 's1');

    final two = await app(semesters: 2);
    addTearDown(two.tasks.dispose);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: buildPlanovaTheme(),
        home: AcademicRecordForm(
          repository: two.tasks,
          clock: two.clock,
          semesterId: 's2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('course-semester')), findsOneWidget);
  });

  testWidgets('Wording: Record session, singular task, no empty reflect card', (
    tester,
  ) async {
    final d = await app();
    addTearDown(d.tasks.dispose);
    await d.tasks.add(
      AcademicTask(
        id: 'quiz',
        title: 'Quiz 1',
        subject: 'DES3113',
        description: '',
        deadline: DateTime(2026, 10, 16, 23, 59),
        estimatedMinutes: 60,
      ),
    );
    await d.plans!.acceptPlan(
      [
        StudySession(
          id: 'pm',
          taskId: 'quiz',
          title: 'Quiz 1',
          subject: 'DES3113',
          startsAt: DateTime(2026, 10, 14, 20),
          minutes: 60,
        ),
      ],
      from: DateTime(2026, 10, 14),
      to: DateTime(2026, 10, 21),
    );
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(find.text('Record session'), findsOneWidget);
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 1 task completed'), findsOneWidget);
    expect(find.text('Make space to reflect'), findsNothing);
  });

  testWidgets('Intro cards use a large icon', (tester) async {
    final d = await app(
      progress: const OnboardingProgress(
        step: 1,
        accountType: AccountType.guest,
      ),
    );
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    final icon = tester.widget<Icon>(find.byIcon(Icons.upload_file_outlined));
    expect(icon.size, 56);
    expect(tester.takeException(), isNull);
  });
}
