import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/data/repositories/study_plan_repository.dart';
import 'package:planova/features/planner/screens/plan_proposal_screen.dart';
import 'package:planova/services/planning/balanced_plan_runner.dart';
import 'package:planova/services/planning/ga_planner.dart';
import 'package:planova/services/planning/rule_based_planner.dart';

import '../../support/scenario_io.dart';
import '../../support/test_apps.dart';
import '../../support/widget_actions.dart';

/// A shared test week where the two methods give different plans.
PlanRequest normalWeek() {
  final week = ScenarioWeek.all().firstWhere((w) => w.id == 'd02-normal-week');
  return PlanRequest(
    tasks: week.tasks,
    availability: week.availability,
    now: week.now,
    settings: week.settings,
  );
}

Future<StudyPlanRepository> mountReview(
  WidgetTester tester,
  PlanRequest request,
) async {
  final d = await realModeApp();
  addTearDown(d.tasks.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    PlanProposalScreen(request: request, repository: d.plans!),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return d.plans!;
}

List<(String?, DateTime, int)> sessionsOf(Iterable<dynamic> sessions) => [
  for (final s in sessions)
    (s.taskId as String?, s.startsAt as DateTime, s.minutes as int),
];

void main() {
  testWidgets('Opens on the balanced plan and accepts it', (tester) async {
    final request = normalWeek();
    final plans = await mountReview(tester, request);
    expect(find.text('BALANCED PLAN · NOTHING SAVED YET'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-comparison')), findsOneWidget);
    expect(find.text('Busiest day'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('proposal-accept')));
    expect(
      sessionsOf(plans.savedSessions),
      sessionsOf(planBalancedFor(request).proposal.sessions),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Switching to earliest first accepts the rule-based plan', (
    tester,
  ) async {
    final request = normalWeek();
    final plans = await mountReview(tester, request);
    await tapVisible(tester, find.byKey(const ValueKey('method-earliest')));
    expect(
      find.text('EARLIEST-FIRST PLAN · NOTHING SAVED YET'),
      findsOneWidget,
    );

    await tapVisible(tester, find.text('How this plan was made'));
    expect(
      find.textContaining('Earliest first: Planova follows fixed rules'),
      findsOneWidget,
    );

    await tapVisible(tester, find.byKey(const ValueKey('proposal-accept')));
    final rules = planWeek(
      tasks: request.tasks,
      availability: request.availability,
      now: request.now,
      settings: request.settings,
    );
    expect(sessionsOf(plans.savedSessions), sessionsOf(rules.sessions));
  });

  testWidgets('Explains the balanced method honestly', (tester) async {
    await mountReview(tester, normalWeek());
    await tapVisible(tester, find.text('How this plan was made'));
    expect(find.textContaining('a genetic algorithm'), findsOneWidget);
    expect(find.textContaining('It is not trained AI'), findsOneWidget);
  });

  testWidgets('Shows progress while the balanced plan is being made', (
    tester,
  ) async {
    final pending = Completer<BalancedPlanResult>();
    final previous = runBalancedPlan;
    runBalancedPlan = (_) => pending.future;
    addTearDown(() => runBalancedPlan = previous);

    final request = normalWeek();
    await mountReviewWithoutSettle(tester, request);
    expect(find.byKey(const ValueKey('balanced-loading')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('proposal-accept')))
          .onPressed,
      isNull,
    );

    // Earliest first is available straight away.
    await tester.tap(find.byKey(const ValueKey('method-earliest')));
    await tester.pump();
    expect(
      find.text('EARLIEST-FIRST PLAN · NOTHING SAVED YET'),
      findsOneWidget,
    );

    pending.complete(planBalancedFor(request));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('method-balanced')));
    await tester.pumpAndSettle();
    expect(find.text('BALANCED PLAN · NOTHING SAVED YET'), findsOneWidget);
  });

  testWidgets('Falls back to earliest first if the balanced plan fails', (
    tester,
  ) async {
    final previous = runBalancedPlan;
    runBalancedPlan = (_) async => throw StateError('test failure');
    addTearDown(() => runBalancedPlan = previous);

    await mountReview(tester, normalWeek());
    expect(
      find.text('EARLIEST-FIRST PLAN · NOTHING SAVED YET'),
      findsOneWidget,
    );
    expect(find.textContaining('could not be made'), findsOneWidget);
    final balanced = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('method-balanced')),
    );
    expect(balanced.onSelected, isNull);
  });

  testWidgets('Comparison fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mountReview(tester, normalWeek());
    expect(find.byKey(const ValueKey('plan-comparison')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The real background runner gives the same plan', (tester) async {
    final request = normalWeek();
    final result = await tester.runAsync(
      () => planBalancedInBackground(request),
    );
    expect(
      encodePlan(result!.proposal),
      encodePlan(planBalancedFor(request).proposal),
    );
    expect(result.score.total, planBalancedFor(request).score.total);
  });
}

Future<void> mountReviewWithoutSettle(
  WidgetTester tester,
  PlanRequest request,
) async {
  final d = await realModeApp();
  addTearDown(d.tasks.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: PlanProposalScreen(request: request, repository: d.plans!),
    ),
  );
  await tester.pump();
}
