import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/theme/app_theme.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/features/ranking/screens/task_ranking_screen.dart';
import 'package:planova/services/ranking/task_ranking_service.dart';

import '../../support/widget_actions.dart';

void main() {
  final asset = File('assets/ranking/provisional_v1.json').readAsStringSync();
  LocalTaskRankingService service() =>
      LocalTaskRankingService(loadModel: () async => asset);

  testWidgets(
    'Tasks entry opens bundled ranking; completed tasks disappear on return',
    (tester) async {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      for (final task in dependencies.tasks.tasks) {
        await dependencies.tasks.update(
          task.copyWith(assessmentWeightPercent: 25),
        );
      }
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('open-task-ranking')));
      expect(find.text('EXPERIMENTAL RANKING'), findsOneWidget);
      await tapVisible(tester, find.text('Database assignment'));
      await tapVisible(tester, find.text('Mark complete'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Suggested order (3)'), 200);
      expect(find.text('Suggested order (3)'), findsOneWidget);
      expect(find.byKey(const ValueKey('rank-database')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Unknown assessment weights remain visible; editing fixes eligibility',
    (tester) async {
      final repo = MockTaskRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPlanovaTheme(),
          home: TaskRankingScreen(
            repository: repo,
            clock: const DemoClock(),
            service: service(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Database assignment'));
      await tapVisible(tester, find.text('Edit task'));
      await tester.ensureVisible(find.byKey(const ValueKey('task-weight')));
      await tester.enterText(find.byKey(const ValueKey('task-weight')), '101');
      tester.testTextInput.hide();
      await tapVisible(tester, find.text('Save task'));
      expect(repo.taskById('database')!.assessmentWeightPercent, isNull);
      await tester.enterText(find.byKey(const ValueKey('task-weight')), '0');
      tester.testTextInput.hide();
      await tapVisible(tester, find.text('Save task'));
      expect(repo.taskById('database')!.assessmentWeightPercent, 0);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Suggested order (1)'), 200);
      expect(find.text('Suggested order (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Ranking fits a small phone with double text and explains experimental limits',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = MockTaskRepository();
      addTearDown(repo.dispose);
      for (final task in repo.tasks) {
        await repo.update(task.copyWith(assessmentWeightPercent: 25));
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPlanovaTheme(),
          home: TaskRankingScreen(
            repository: repo,
            clock: const DemoClock(),
            service: service(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('About this ranking'));
      await tester.pumpAndSettle();
      expect(find.text('About this ranking'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Model failure offers retry and preserves saved tasks', (
    tester,
  ) async {
    final repo = MockTaskRepository();
    addTearDown(repo.dispose);
    var attempts = 0;
    final failing = LocalTaskRankingService(
      loadModel: () async {
        if (attempts++ == 0) throw const FormatException('Bad model');
        return asset;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPlanovaTheme(),
        home: TaskRankingScreen(
          repository: repo,
          clock: const DemoClock(),
          service: failing,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Try again'));
    expect(repo.tasks.length, 5);
    expect(find.text('Try again'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
