import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/data/mock/mock_study_repository.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/data/repositories/availability_repository.dart';
import 'package:planova/models/academic_task.dart';

import '../../support/widget_actions.dart';

/// Like the real app on first launch: no tasks, no samples, empty week.
Future<AppDependencies> emptyApp() async {
  final tasks = MockTaskRepository();
  for (final task in tasks.tasks.toList()) {
    await tasks.delete(task.id);
  }
  return AppDependencies(
    tasks: tasks,
    study: MockStudyRepository(tasks: tasks, includeSamples: false),
    clock: const DemoClock(),
    availability: MemoryAvailabilityRepository(),
  );
}

AcademicTask undated(String id, String title) => AcademicTask(
  id: id,
  title: title,
  subject: 'DES3113 · Mobile',
  description: '',
  estimatedMinutes: 300,
  assessmentWeightPercent: 20,
);

void main() {
  testWidgets(
    'Needs your input lists undated tasks and the sheet adds a date',
    (tester) async {
      final d = await emptyApp();
      addTearDown(d.tasks.dispose);
      for (var i = 1; i <= 5; i++) {
        await d.tasks.add(undated('t$i', 'Assessment $i'));
      }
      await tester.pumpWidget(MyApp(dependencies: d));
      await tester.pumpAndSettle();
      expect(find.text('Needs your input · 5'), findsOneWidget);
      expect(find.text('Assessment 4'), findsNothing);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('needs-input-toggle')),
      );
      expect(find.text('Assessment 5'), findsOneWidget);

      // "Decide later" changes nothing.
      await tapVisible(tester, find.byKey(const ValueKey('needs-input-t1')));
      expect(find.text('When is it due?'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('sheet-later')));
      expect(d.tasks.taskById('t1')!.deadline, isNull);

      // Choosing a date and saving removes it from the list.
      await tapVisible(tester, find.byKey(const ValueKey('needs-input-t1')));
      await tapVisible(tester, find.byKey(const ValueKey('sheet-due-date')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await enterEffort(tester, 'sheet-effort', hours: '6');
      await tapVisible(tester, find.byKey(const ValueKey('sheet-save')));
      final saved = d.tasks.taskById('t1')!;
      expect(saved.deadline, DateTime(2026, 10, 14, 23, 59));
      expect(saved.estimatedMinutes, 360);
      expect(find.text('Needs your input · 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Needs-input sheet and setup links fit a small phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final d = await emptyApp();
      addTearDown(d.tasks.dispose);
      await d.tasks.add(undated('t1', 'Assessment with a long title here'));
      await tester.pumpWidget(MyApp(dependencies: d));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.byKey(const ValueKey('needs-input-t1')));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.byKey(const ValueKey('sheet-later')));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('setup-availability')),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
