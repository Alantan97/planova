import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/data/local/local_profile_repository.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/data/repositories/availability_repository.dart';
import 'package:planova/data/repositories/profile_repository.dart';
import 'package:planova/data/repositories/study_plan_repository.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/onboarding_progress.dart';
import 'package:sembast/sembast_io.dart';

import '../../support/widget_actions.dart';

/// A brand-new student: no data, journey not started.
Future<AppDependencies> newStudent({
  OnboardingProgress progress = const OnboardingProgress(),
}) async {
  final tasks = MockTaskRepository();
  for (final t in tasks.tasks.toList()) {
    await tasks.delete(t.id);
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

Future<void> next(WidgetTester tester) =>
    tapVisible(tester, find.byKey(const ValueKey('onboarding-next')));

void main() {
  test('Profile storage: new vs existing students, and restart', () async {
    final round = ProfileCodec.decode(
      ProfileCodec.encode(
        const OnboardingProgress(
          step: 4,
          displayName: 'Sam',
          accountType: AccountType.guest,
        ),
      ),
    );
    expect(round.step, 4);
    expect(round.displayName, 'Sam');
    expect(round.accountType, AccountType.guest);
    expect(round.completed, isFalse);

    final dir = await Directory.systemTemp.createTemp('planova_profile_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}records.db';
    var db = await databaseFactoryIo.openDatabase(path);
    var repo = await LocalProfileRepository.open(db, hasExistingData: true);
    expect(repo.progress.completed, isTrue, reason: 'existing users skip it');
    repo = await LocalProfileRepository.open(db, hasExistingData: false);
    expect(repo.progress.completed, isFalse, reason: 'new users see it');
    await repo.save(repo.progress.copyWith(step: 5, displayName: 'Sam'));
    await repo.close();
    await db.close();

    db = await databaseFactoryIo.openDatabase(path);
    repo = await LocalProfileRepository.open(db, hasExistingData: true);
    expect(repo.progress.step, 5, reason: 'saved progress wins');
    expect(repo.progress.completed, isFalse);
    await repo.close();
    await db.close();
  });

  testWidgets('A new student goes from welcome to Today with a plan', (
    tester,
  ) async {
    final d = await newStudent();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();

    // 0 · Welcome: Google is an honest placeholder that continues as guest.
    expect(
      find.text('Plan your semester, one week at a time.'),
      findsOneWidget,
    );
    await tapVisible(tester, find.byKey(const ValueKey('onboarding-google')));
    expect(find.text('Google sign-in is coming'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('google-unavailable-ok')),
    );
    expect(d.profile.progress.accountType, AccountType.guest);

    // 1 · How Planova works: three cards.
    expect(find.text('Import your courses'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('onboarding-intro-next')),
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('onboarding-intro-next')),
    );
    expect(find.text('Record and adjust'), findsOneWidget);
    await tapVisible(tester, find.text('Get started'));

    // 2 · About you (optional).
    expect(find.text('STEP 1 OF 7 · ABOUT YOU'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-name')),
      'Sam',
    );
    await tester.pump();
    await next(tester);
    expect(d.profile.progress.displayName, 'Sam');

    // 3 · Semester.
    expect(find.text('STEP 2 OF 7 · SEMESTER'), findsOneWidget);
    await next(tester);
    expect(find.text('Enter a semester name.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('setup-semester-name')),
      'Semester 1 · 2026/2027',
    );
    await next(tester);
    expect(d.tasks.semesters, hasLength(1));

    // 4 · Courses (an import is simulated by saving a course and tasks).
    expect(find.text('STEP 3 OF 7 · COURSES'), findsOneWidget);
    final semesterId = d.tasks.semesters.single.id;
    await d.tasks.saveCourse(
      AcademicCourse(
        id: 'c1',
        semesterId: semesterId,
        code: 'DES3113',
        name: 'Mobile',
      ),
      isNew: true,
    );
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
    await d.tasks.add(
      const AcademicTask(
        id: 'exam',
        title: 'Final exam',
        subject: 'DES3113 · Mobile',
        description: '',
        estimatedMinutes: 120,
        courseId: 'c1',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DES3113 · Mobile'), findsOneWidget);
    await next(tester);

    // 5 · Your week.
    expect(find.text('STEP 4 OF 7 · YOUR WEEK'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('preset-weekday-evenings')),
    );
    await next(tester);

    // 6 · Missing due dates: skippable.
    expect(find.text('STEP 5 OF 7 · DUE DATES'), findsOneWidget);
    expect(find.text('Needs your input · 1'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    await next(tester);

    // 7 · First plan: review and accept.
    expect(find.text('STEP 6 OF 7 · FIRST PLAN'), findsOneWidget);
    expect(find.text('1 session · 1h · 1 task'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('onboarding-review-plan')),
    );
    await tapVisible(tester, find.byKey(const ValueKey('proposal-accept')));
    expect(d.plans!.hasPlan, isTrue);
    expect(
      find.text('Plan saved. You will see it on Today and Plan.'),
      findsOneWidget,
    );
    await next(tester);

    // 8 · Done → Today.
    expect(find.text('You are all set, Sam.'), findsOneWidget);
    await next(tester);
    expect(d.profile.progress.completed, isTrue);
    expect(find.text('Hi, Sam'), findsOneWidget);
    expect(find.textContaining('GET STARTED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Finish later goes to Today; the guide resumes at that step', (
    tester,
  ) async {
    final d = await newStudent(
      progress: const OnboardingProgress(
        step: 3,
        accountType: AccountType.guest,
      ),
    );
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 7 · SEMESTER'), findsOneWidget);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('onboarding-finish-later')),
    );
    expect(find.text('GET STARTED · 0 OF 3 DONE'), findsOneWidget);
    expect(d.profile.progress.step, 3);

    await tapVisible(tester, find.byKey(const ValueKey('setup-guided')));
    expect(find.text('STEP 2 OF 7 · SEMESTER'), findsOneWidget);

    // Back goes to the previous screen, not out of the journey.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 7 · ABOUT YOU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Journey screens fit a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final d = await newStudent();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.byKey(const ValueKey('onboarding-guest')));
    expect(tester.takeException(), isNull);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('onboarding-intro-skip')),
    );
    for (var i = 0; i < 6; i++) {
      await next(tester);
      expect(tester.takeException(), isNull);
      if (find.text('Enter a semester name.').evaluate().isNotEmpty) {
        await tester.enterText(
          find.byKey(const ValueKey('setup-semester-name')),
          'Semester 1',
        );
        await next(tester);
      }
    }
    expect(find.textContaining('You are all set'), findsOneWidget);
  });
}
