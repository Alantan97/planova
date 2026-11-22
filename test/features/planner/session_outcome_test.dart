import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/data/local/local_availability_repository.dart';
import 'package:planova/data/local/local_study_plan_repository.dart';
import 'package:planova/data/local/local_task_repository.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/data/repositories/availability_repository.dart';
import 'package:planova/data/repositories/study_plan_repository.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/study_session.dart';
import 'package:planova/models/weekly_availability.dart';
import 'package:sembast/sembast_io.dart';

import '../../support/widget_actions.dart';

/// The preview clock is Wednesday 14 October 2026, 13:00.
final morning = DateTime(2026, 10, 14, 10); // already over
final evening = DateTime(2026, 10, 14, 20); // still to come

AcademicTask quiz({int estimate = 120}) => AcademicTask(
  id: 'quiz',
  title: 'Quiz 1',
  subject: 'DES3113 · Mobile',
  description: '',
  deadline: DateTime(2026, 10, 16, 23, 59),
  estimatedMinutes: estimate,
);

StudySession session(String id, DateTime at) => StudySession(
  id: id,
  taskId: 'quiz',
  title: 'Quiz 1',
  subject: 'DES3113 · Mobile',
  startsAt: at,
  minutes: 60,
);

Future<(MockTaskRepository, MemoryStudyPlanRepository)> memory({
  int estimate = 120,
}) async {
  final tasks = MockTaskRepository();
  for (final t in tasks.tasks.toList()) {
    await tasks.delete(t.id);
  }
  await tasks.add(quiz(estimate: estimate));
  final availability = MemoryAvailabilityRepository();
  await availability.saveWindow(
    StudyWindow(
      id: 'w',
      range: WeeklyTimeRange(
        weekdays: [1, 2, 3, 4, 5],
        startMinute: 9 * 60,
        endMinute: 22 * 60,
      ),
    ),
  );
  final plans = MemoryStudyPlanRepository(
    tasks: tasks,
    availability: availability,
  );
  await plans.acceptPlan(
    [session('am', morning), session('pm', evening)],
    from: DateTime(2026, 10, 14),
    to: DateTime(2026, 10, 21),
  );
  return (tasks, plans);
}

Future<AppDependencies> app() async {
  final (tasks, plans) = await memory();
  return AppDependencies(
    tasks: tasks,
    study: plans,
    clock: const DemoClock(),
    availability: plans.availability,
    plans: plans,
  );
}

void main() {
  group('Recording outcomes', () {
    test('Done adds the session to the task and to this week', () async {
      final (tasks, plans) = await memory();
      await plans.recordOutcome('am', SessionStatus.completed);
      expect(tasks.taskById('quiz')!.completedMinutes, 60);
      expect(plans.completedMinutesInWeek(morning), 60);
      expect(plans.plannedMinutesInWeek(morning), 120);
      expect(plans.needsReplan, isFalse);
    });

    test('Corrections never double-count', () async {
      final (tasks, plans) = await memory();
      await plans.recordOutcome(
        'am',
        SessionStatus.partial,
        recordedMinutes: 20,
      );
      expect(tasks.taskById('quiz')!.completedMinutes, 20);
      expect(plans.needsReplan, isTrue);
      await plans.recordOutcome('am', SessionStatus.completed);
      expect(tasks.taskById('quiz')!.completedMinutes, 60);
      await plans.recordOutcome('am', SessionStatus.missed);
      expect(tasks.taskById('quiz')!.completedMinutes, 0);
      expect(
        () => plans.recordOutcome('am', SessionStatus.partial),
        throwsFormatException,
      );
    });

    test('Studying beyond the estimate grows the estimate', () async {
      final (tasks, plans) = await memory(estimate: 30);
      await plans.recordOutcome('am', SessionStatus.completed);
      final task = tasks.taskById('quiz')!;
      expect(task.completedMinutes, 60);
      expect(task.estimatedMinutes, 60);
    });

    test('Re-planning clears the flag and keeps recorded history', () async {
      final (_, plans) = await memory();
      await plans.recordOutcome('am', SessionStatus.missed);
      expect(plans.unrecordedBefore(DateTime(2026, 10, 14, 13)), isEmpty);
      await plans.acceptPlan(
        [session('new', DateTime(2026, 10, 15, 20))],
        from: DateTime(2026, 10, 14, 13),
        to: DateTime(2026, 10, 21),
      );
      expect(plans.needsReplan, isFalse);
      expect(plans.savedSessions.map((s) => s.id), ['am', 'new']);
      expect(plans.savedSessions.first.status, SessionStatus.missed);
    });

    test('Outcomes and the re-plan flag survive a restart', () async {
      final dir = await Directory.systemTemp.createTemp('planova_outcome_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}records.db';
      Future<(LocalTaskRepository, LocalStudyPlanRepository)> open() async {
        final db = await databaseFactoryIo.openDatabase(path);
        final tasks = await LocalTaskRepository.open(db);
        final availability = await LocalAvailabilityRepository.open(db);
        return (
          tasks,
          await LocalStudyPlanRepository.open(
            db,
            tasks: tasks,
            availability: availability,
          ),
        );
      }

      var (tasks, plans) = await open();
      await tasks.add(quiz());
      await plans.acceptPlan(
        [session('am', morning)],
        from: DateTime(2026, 10, 14),
        to: DateTime(2026, 10, 21),
      );
      await plans.recordOutcome(
        'am',
        SessionStatus.partial,
        recordedMinutes: 25,
      );
      await plans.close();
      await tasks.close();

      (tasks, plans) = await open();
      final saved = plans.savedSessions.single;
      expect(saved.status, SessionStatus.partial);
      expect(saved.recordedMinutes, 25);
      expect(plans.needsReplan, isTrue);
      expect(tasks.taskById('quiz')!.completedMinutes, 25);
      await plans.close();
      await tasks.close();
    });
  });

  testWidgets('Missed session on Today leads to a reviewed re-plan', (
    tester,
  ) async {
    final d = await app();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(find.text('Did you do this? · 1'), findsOneWidget);
    expect(find.text('Your plan needs updating'), findsNothing);

    await tapVisible(
      tester,
      find.text('60 min · Study session · tap to record').first,
    );
    expect(find.text('HOW DID IT GO?'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('record-missed')));
    await tapVisible(tester, find.byKey(const ValueKey('record-save')));
    expect(
      find.text('Marked as missed. Re-plan from Today when you are ready.'),
      findsOneWidget,
    );
    expect(find.text('Did you do this? · 1'), findsNothing);
    expect(find.text('Your plan needs updating'), findsOneWidget);
    expect(find.text('60 min · Missed'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('today-replan')));
    expect(find.text('RULE-BASED PLAN · NOTHING SAVED YET'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('proposal-accept')));
    expect(d.plans!.needsReplan, isFalse);
    expect(find.text('RULE-BASED PLAN · NOTHING SAVED YET'), findsNothing);
    expect(find.text('Your plan needs updating'), findsNothing);
    expect(
      d.plans!.savedSessions.where((s) => s.status == SessionStatus.missed),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Partly done and done update the row, task and week progress', (
    tester,
  ) async {
    final d = await app();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-plan')));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Quiz 1').first);
    await tapVisible(tester, find.byKey(const ValueKey('record-partial')));
    await tapVisible(tester, find.byKey(const ValueKey('record-save')));
    expect(find.text('Enter the minutes you studied.'), findsOneWidget);
    await enterEffort(tester, 'record-minutes', minutes: '60');
    await tapVisible(tester, find.byKey(const ValueKey('record-save')));
    expect(
      find.text('That is the whole session. Choose Done instead.'),
      findsOneWidget,
    );
    await enterEffort(tester, 'record-minutes', minutes: '20');
    await tapVisible(tester, find.byKey(const ValueKey('record-save')));
    expect(find.text('60 min · Partly done · 20m recorded'), findsOneWidget);
    expect(d.tasks.taskById('quiz')!.completedMinutes, 20);

    // Reopening shows the recorded outcome and allows a correction.
    await tapVisible(tester, find.text('60 min · Partly done · 20m recorded'));
    expect(find.text('RECORDED · CHANGE IF NEEDED'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('record-completed')));
    await tapVisible(tester, find.byKey(const ValueKey('record-save')));
    expect(find.text('60 min · Done · 1h recorded'), findsOneWidget);
    expect(d.tasks.taskById('quiz')!.completedMinutes, 60);

    await tester.ensureVisible(find.text('THIS WEEK · STUDIED'));
    await tester.pumpAndSettle();
    expect(find.text('THIS WEEK · STUDIED'), findsOneWidget);
    expect(
      find.textContaining('2h planned', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('When no work is left, the snack bar offers Mark complete', (
    tester,
  ) async {
    final (tasks, plans) = await memory(estimate: 60);
    addTearDown(tasks.dispose);
    final d = AppDependencies(
      tasks: tasks,
      study: plans,
      clock: const DemoClock(),
      availability: plans.availability,
      plans: plans,
    );
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.text('60 min · Study session · tap to record').first,
    );
    await tapVisible(tester, find.byKey(const ValueKey('record-completed')));
    await tapVisible(tester, find.byKey(const ValueKey('record-save')));
    expect(find.text('Recorded. No work left on Quiz 1.'), findsOneWidget);
    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();
    expect(tasks.taskById('quiz')!.isCompleted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Record sheet fits a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final d = await app();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('Did you do this? · 1'));
    await tapVisible(tester, find.textContaining('tap to record').first);
    await tapVisible(tester, find.byKey(const ValueKey('record-partial')));
    expect(tester.takeException(), isNull);
  });
}
