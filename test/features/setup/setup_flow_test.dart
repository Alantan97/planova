import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/data/mock/mock_study_repository.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/data/repositories/availability_repository.dart';
import 'package:planova/models/academic_course.dart';
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

/// The weekly total sits at the bottom of the step; scroll down to read it,
/// then back to the top for the next tap.
Future<String> freeTime(WidgetTester tester) async {
  final total = find.byKey(const ValueKey('setup-free-time'));
  final list = find.byType(Scrollable).last;
  await tester.scrollUntilVisible(total, 300, scrollable: list);
  final text = tester.widget<Text>(total).data!;
  await tester.drag(list, const Offset(0, 2000));
  await tester.pumpAndSettle();
  return text;
}

void main() {
  testWidgets('Guided setup saves each step and the card disappears', (
    tester,
  ) async {
    final d = await emptyApp();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('setup-continue')));
    expect(find.text('STEP 1 OF 3 · SEMESTER'), findsOneWidget);

    // Step 1: the semester name is required, then it is saved.
    await tapVisible(tester, find.byKey(const ValueKey('setup-next')));
    expect(find.text('Enter a semester name.'), findsOneWidget);
    expect(d.tasks.semesters, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('setup-semester-name')),
      'Semester 1 · 2026/2027',
    );
    await tapVisible(tester, find.byKey(const ValueKey('setup-next')));
    expect(d.tasks.semesters.single.name, 'Semester 1 · 2026/2027');

    // Step 2: courses can be skipped; a course added meanwhile is listed.
    expect(find.text('STEP 2 OF 3 · COURSES'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    await d.tasks.saveCourse(
      AcademicCourse(
        id: 'c1',
        semesterId: d.tasks.semesters.single.id,
        code: 'DES3113',
        name: 'Mobile',
      ),
      isNew: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('DES3113 · Mobile'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('setup-next')));

    // Step 3: presets toggle saved study windows; the total updates.
    expect(find.text('STEP 3 OF 3 · AVAILABILITY'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('preset-weekday-evenings')),
    );
    expect(
      d.availability.availability.windows.single.id,
      'preset-weekday-evenings',
    );
    expect(await freeTime(tester), '10h');
    await tapVisible(
      tester,
      find.byKey(const ValueKey('preset-weekend-mornings')),
    );
    expect(await freeTime(tester), '16h');
    await tapVisible(
      tester,
      find.byKey(const ValueKey('preset-weekend-mornings')),
    );
    expect(d.availability.availability.windows.length, 1);
    await tapVisible(tester, find.byKey(const ValueKey('setup-next')));

    // Back on Today: setup complete, checklist gone.
    expect(find.textContaining('GET STARTED'), findsNothing);
    expect(
      find.text('Setup saved. Today lists anything still missing.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Finish later keeps what was saved and resumes at the next step',
    (tester) async {
      final d = await emptyApp();
      addTearDown(d.tasks.dispose);
      await tester.pumpWidget(MyApp(dependencies: d));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('setup-continue')));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('setup-finish-later')),
      );
      expect(d.tasks.semesters, isEmpty);
      expect(find.text('GET STARTED · 0 OF 3 DONE'), findsOneWidget);

      await d.tasks.saveSemester(
        AcademicSemester(
          id: 's1',
          name: 'Semester 1',
          startDate: DateTime(2026, 10),
          endDate: DateTime(2027, 2),
        ),
        isNew: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue setup'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('setup-continue')));
      expect(find.text('STEP 2 OF 3 · COURSES'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      // Step 1 shows the saved semester instead of an empty form.
      expect(find.text('Semester 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-semester-name')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('Setup steps and the sheet fit a small phone with large text', (
    tester,
  ) async {
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
    await tapVisible(tester, find.byKey(const ValueKey('setup-availability')));
    expect(tester.takeException(), isNull);
  });
}
