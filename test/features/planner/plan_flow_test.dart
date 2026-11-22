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

AcademicTask quiz() => AcademicTask(
  id: 'quiz',
  title: 'Quiz 1',
  subject: 'DES3113 · Mobile',
  description: '',
  deadline: DateTime(2026, 10, 16, 23, 59),
  estimatedMinutes: 60,
);

final evenings = StudyWindow(
  id: 'w',
  range: WeeklyTimeRange(
    weekdays: [1, 2, 3, 4, 5],
    startMinute: 20 * 60,
    endMinute: 22 * 60,
  ),
);

StudySession planned(String id, DateTime at, {String taskId = 'quiz'}) =>
    StudySession(
      id: id,
      taskId: taskId,
      title: 'Quiz 1',
      subject: 'DES3113',
      startsAt: at,
      minutes: 60,
    );

/// Real-mode app (no samples) with one dated task and weekday evenings free.
Future<AppDependencies> plannableApp() async {
  final tasks = MockTaskRepository();
  for (final t in tasks.tasks.toList()) {
    await tasks.delete(t.id);
  }
  await tasks.add(quiz());
  final availability = MemoryAvailabilityRepository();
  await availability.saveWindow(evenings);
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
  );
}

void main() {
  test(
    'Plan storage round-trips, replaces only the plan period, survives restart',
    () async {
      final decoded = StudyPlanCodec.decode(
        StudyPlanCodec.encode(
          StudyPlanState([
            planned('a', DateTime(2026, 10, 14, 20)),
          ], needsReplan: false),
        ),
      );
      expect(decoded.sessions.single.startsAt, DateTime(2026, 10, 14, 20));
      // Plans saved by the previous version (schema 1) still load.
      final v1 = StudyPlanCodec.decode({
        'schemaVersion': 1,
        'sessions': [
          {
            'id': 'old',
            'taskId': 'quiz',
            'title': 'Quiz 1',
            'subject': 'DES3113',
            'startsAt': DateTime(2026, 10, 14, 20).toIso8601String(),
            'minutes': 60,
            'status': 'planned',
          },
        ],
      });
      expect(v1.sessions.single.id, 'old');
      expect(v1.needsReplan, isFalse);
      expect(
        () => StudyPlanCodec.decode({'schemaVersion': 9, 'sessions': []}),
        throwsFormatException,
      );

      final dir = await Directory.systemTemp.createTemp('planova_plan_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}records.db';
      Future<(LocalTaskRepository, LocalStudyPlanRepository)> open() async {
        final db = await databaseFactoryIo.openDatabase(path);
        final tasks = await LocalTaskRepository.open(db);
        final availability = await LocalAvailabilityRepository.open(db);
        final plans = await LocalStudyPlanRepository.open(
          db,
          tasks: tasks,
          availability: availability,
        );
        return (tasks, plans);
      }

      var (tasks, plans) = await open();
      await tasks.add(quiz());
      await plans.acceptPlan(
        [planned('old-in', DateTime(2026, 10, 15, 20))],
        from: DateTime(2026, 10, 14, 13),
        to: DateTime(2026, 10, 21),
      );
      await plans.acceptPlan(
        [planned('outside', DateTime(2026, 10, 22, 20))],
        from: DateTime(2026, 10, 22),
        to: DateTime(2026, 10, 29),
      );
      // Re-plan the first week: its old session is replaced, the other kept.
      await plans.acceptPlan(
        [planned('new-in', DateTime(2026, 10, 16, 20))],
        from: DateTime(2026, 10, 14, 13),
        to: DateTime(2026, 10, 21),
      );
      await plans.close();
      await tasks.close();

      (tasks, plans) = await open();
      expect(plans.savedSessions.map((s) => s.id), ['new-in', 'outside']);
      expect(plans.hasPlan, isTrue);
      expect(plans.showsSampleSessions, isFalse);
      // A planned session disappears from the day once its task is completed.
      expect(plans.sessionsOn(DateTime(2026, 10, 16)).single.id, 'new-in');
      await tasks.setCompleted('quiz', true);
      expect(plans.sessionsOn(DateTime(2026, 10, 16)), isEmpty);
      await plans.close();
      await tasks.close();
    },
  );

  testWidgets('Create, review, cancel and accept a plan; Today shows it', (
    tester,
  ) async {
    final d = await plannableApp();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(
      find.text('No study sessions today. Create a plan on the Plan tab.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('nav-plan')));
    await tester.pumpAndSettle();
    expect(find.text('No study plan yet'), findsOneWidget);

    // Cancel saves nothing.
    await tapVisible(tester, find.byKey(const ValueKey('create-plan')));
    expect(find.text('RULE-BASED PLAN · NOTHING SAVED YET'), findsOneWidget);
    expect(find.text('1 session · 1h · 1 task'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('proposal-cancel')));
    expect(d.plans!.hasPlan, isFalse);

    // Accept saves it; the Plan tab and Today show the session.
    await tapVisible(tester, find.byKey(const ValueKey('create-plan')));
    await tapVisible(tester, find.byKey(const ValueKey('proposal-accept')));
    expect(d.plans!.savedSessions.single.startsAt, DateTime(2026, 10, 14, 20));
    expect(find.text('Plan saved · 1 study session.'), findsOneWidget);
    expect(
      find.text('Rule-based plan · Fixed commitments shown in grey'),
      findsOneWidget,
    );
    expect(find.text('Re-plan the next 7 days'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-today')));
    await tester.pumpAndSettle();
    expect(find.text('Quiz 1'), findsWidgets);
    expect(find.text('1 study session · 1h planned'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Proposal explains missing availability and unplanned tasks', (
    tester,
  ) async {
    final d = await plannableApp();
    addTearDown(d.tasks.dispose);
    await d.availability.deleteWindow('w');
    await d.tasks.add(
      const AcademicTask(
        id: 'undated',
        title: 'Final exam',
        subject: 'DES3113 · Mobile',
        description: '',
        estimatedMinutes: 120,
      ),
    );
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-plan')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('create-plan')));
    expect(find.text('No sessions could be planned'), findsOneWidget);
    expect(find.text('Set your weekly availability first'), findsOneWidget);
    await tapVisible(tester, find.text('Final exam'));
    expect(find.textContaining('Needs a due date'), findsOneWidget);
    final accept = tester.widget<FilledButton>(
      find.byKey(const ValueKey('proposal-accept')),
    );
    expect(accept.onPressed, isNull);
    // Back to the top of the proposal, where the availability notice sits.
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Set availability'));
    expect(find.text('Your normal week.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Proposal fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final d = await plannableApp();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-plan')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('create-plan')));
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('How this plan was made'));
    expect(tester.takeException(), isNull);
  });
}
