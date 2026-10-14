import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/main.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable && widget.restorationId != 'editable',
          )
          .last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Create, edit, complete, reopen, and delete a task across screens',
    (tester) async {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.tasks.dispose);
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Add task'));
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Write literature review',
      );
      await tester.enterText(
        find.byKey(const ValueKey('task-subject')),
        'Final Year Project',
      );
      await tester.enterText(
        find.byKey(const ValueKey('task-duration')),
        '120',
      );
      tester.testTextInput.hide();
      await tapVisible(tester, find.text('Save task'));
      expect(dependencies.tasks.tasks.length, 6);
      await tapVisible(tester, find.text('Write literature review'));
      await tapVisible(tester, find.text('Edit task'));
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Review related work',
      );
      tester.testTextInput.hide();
      await tapVisible(tester, find.text('Save task'));
      expect(dependencies.tasks.tasks.last.title, 'Review related work');
      await tapVisible(tester, find.text('Mark complete'));
      expect(dependencies.tasks.tasks.last.isCompleted, isTrue);
      expect(dependencies.tasks.tasks.last.completedMinutes, 0);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 6 tasks completed'), findsOneWidget);
      expect(find.textContaining('3h 30m', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Review related work'));
      await tapVisible(tester, find.text('Mark active'));
      expect(dependencies.tasks.tasks.last.isCompleted, isFalse);
      await tapVisible(tester, find.text('Delete task'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(dependencies.tasks.tasks.length, 6);
      await tapVisible(tester, find.text('Delete task'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(dependencies.tasks.tasks.length, 5);
      expect(find.text('Review related work'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Task form validates fields and fits with enlarged text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.tasks.dispose);
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Add task'));
      await tapVisible(tester, find.text('Save task'));
      expect(dependencies.tasks.tasks.length, 5);
      await tester.ensureVisible(find.byKey(const ValueKey('task-title')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a task title.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('task-title')), '   ');
      await tester.ensureVisible(find.byKey(const ValueKey('task-duration')));
      await tester.enterText(find.byKey(const ValueKey('task-duration')), '0');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      tester.testTextInput.hide();
      await tapVisible(tester, find.text('Save task'));
      expect(dependencies.tasks.tasks.length, 5);
      await tester.ensureVisible(find.byKey(const ValueKey('task-duration')));
      await tester.pumpAndSettle();
      expect(find.text('Enter 1–10080 minutes.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(dependencies.tasks.tasks.length, 5);
    },
  );

  test('Completion and deletion remove planned sessions without altering recorded hours', () async {
    final dependencies = AppDependencies.demo();
    addTearDown(dependencies.tasks.dispose);
    await dependencies.tasks.setCompleted('graphs', true);
    expect(
      dependencies.study
          .sessionsOn(DateTime(2026, 10, 14))
          .any((session) => session.taskId == 'graphs'),
      isFalse,
    );
    await dependencies.tasks.setCompleted('graphs', false);
    expect(
      dependencies.study
          .sessionsOn(DateTime(2026, 10, 14))
          .any((session) => session.taskId == 'graphs'),
      isTrue,
    );
    await dependencies.tasks.delete('database');
    expect(
      dependencies.study
          .sessionsOn(DateTime(2026, 10, 14))
          .any((session) => session.taskId == 'database'),
      isFalse,
    );
    expect(
      dependencies.study.completedMinutesInWeek(DateTime(2026, 10, 14)),
      210,
    );
  });
}
