import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/core/widgets/effort_field.dart';
import 'package:planova/models/academic_course.dart';

import '../../support/widget_actions.dart';

AcademicSemester semester(String id) => AcademicSemester(
  id: id,
  name: 'Semester $id',
  startDate: DateTime(2026, 10),
  endDate: DateTime(2027, 2),
);

Future<void> pumpTasksTab(WidgetTester tester, AppDependencies d) async {
  await tester.pumpWidget(MyApp(dependencies: d));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('nav-courses')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Effort field shows hours and minutes and stores minutes', (
    tester,
  ) async {
    final controller = TextEditingController(text: '90');
    addTearDown(controller.dispose);
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: form,
            child: EffortField(
              controller: controller,
              fieldKey: 'effort',
              label: 'Effort',
              validate: validateEffort,
            ),
          ),
        ),
      ),
    );
    TextField box(String part) =>
        tester.widget<TextField>(find.byKey(ValueKey('effort-$part')));
    expect(box('hours').controller!.text, '1');
    expect(box('minutes').controller!.text, '30');

    await enterEffort(tester, 'effort', hours: '2', minutes: '15');
    expect(controller.text, '135');

    await tester.tap(find.byKey(const ValueKey('effort-quick-300')));
    await tester.pump();
    expect(controller.text, '300');
    expect(box('hours').controller!.text, '5');
    expect(box('minutes').controller!.text, '');

    await enterEffort(tester, 'effort');
    expect(controller.text, '');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      find.text('Enter a time from 1 minute to 168 hours.'),
      findsOneWidget,
    );
    expect(validateEffort(30, recorded: 90), contains('1 h 30 min'));
    expect(validateEffort(169 * 60), isNotNull);
    expect(validateEffort(168 * 60), isNull);
  });

  testWidgets('Import proforma on Tasks asks for a semester when none exist', (
    tester,
  ) async {
    final d = AppDependencies.demo();
    addTearDown(d.tasks.dispose);
    await pumpTasksTab(tester, d);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('tasks-import-proforma')),
    );
    expect(
      find.text('Add your semester first, then import its proformas.'),
      findsOneWidget,
    );
    expect(find.text('Your courses.'), findsOneWidget);
  });

  testWidgets('Import proforma goes straight to import for one semester', (
    tester,
  ) async {
    final d = AppDependencies.demo();
    addTearDown(d.tasks.dispose);
    await d.tasks.saveSemester(semester('1'), isNew: true);
    await pumpTasksTab(tester, d);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('tasks-import-proforma')),
    );
    expect(find.widgetWithText(AppBar, 'Import proforma'), findsOneWidget);
  });

  testWidgets('Import proforma lets you choose among several semesters', (
    tester,
  ) async {
    final d = AppDependencies.demo();
    addTearDown(d.tasks.dispose);
    await d.tasks.saveSemester(semester('1'), isNew: true);
    await d.tasks.saveSemester(semester('2'), isNew: true);
    await pumpTasksTab(tester, d);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('tasks-import-proforma')),
    );
    expect(find.text('Import into which semester?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-semester-2')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Import proforma'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tasks actions and effort fit a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final d = AppDependencies.demo();
    addTearDown(d.tasks.dispose);
    await pumpTasksTab(tester, d);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('Add task').first);
    await tester.ensureVisible(
      find.byKey(const ValueKey('task-duration-hours')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
