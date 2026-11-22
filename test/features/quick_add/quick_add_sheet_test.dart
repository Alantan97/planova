import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/app/widgets/planova_nav_bar.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/study_session.dart';

import '../../support/test_apps.dart';
import '../../support/widget_actions.dart';

/// The preview clock is Wednesday 14 October 2026, 13:00.
StudySession _session(String id, DateTime at) => StudySession(
  id: id,
  taskId: 'quiz',
  title: 'Quiz 1',
  subject: 'DES3111',
  startsAt: at,
  minutes: 60,
);

Future<AppDependencies> _withQuiz() async {
  final d = await realModeApp(courses: 1);
  await d.tasks.add(
    AcademicTask(
      id: 'quiz',
      title: 'Quiz 1',
      subject: 'DES3111',
      courseId: 'c1',
      description: '',
      deadline: DateTime(2026, 10, 20, 23, 59),
      estimatedMinutes: 180,
    ),
  );
  return d;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('quick-add')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('The + opens the same sheet and never switches tab', (
    tester,
  ) async {
    final d = await realModeApp();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-courses')));
    await tester.pumpAndSettle();
    await _openSheet(tester);
    for (final key in ['task', 'session', 'commitment', 'proforma']) {
      expect(find.byKey(ValueKey('quick-add-$key')), findsOneWidget);
    }
    await tester.tapAt(const Offset(10, 10)); // dismiss
    await tester.pumpAndSettle();
    final bar = tester.widget<PlanovaNavBar>(find.byType(PlanovaNavBar));
    expect(bar.selectedIndex, 2, reason: 'Courses stays selected');
  });

  testWidgets('Task or assessment opens the task form', (tester) async {
    final d = await realModeApp(courses: 1);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await _openSheet(tester);
    await tapVisible(tester, find.byKey(const ValueKey('quick-add-task')));
    expect(find.byKey(const ValueKey('task-title')), findsOneWidget);
  });

  testWidgets('Class or commitment opens the commitment form', (tester) async {
    final d = await realModeApp();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await _openSheet(tester);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('quick-add-commitment')),
    );
    expect(find.byKey(const ValueKey('save-time-block')), findsOneWidget);
  });

  testWidgets('Recording with no plan says to create one first', (
    tester,
  ) async {
    final d = await _withQuiz();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await _openSheet(tester);
    await tapVisible(tester, find.byKey(const ValueKey('quick-add-session')));
    expect(find.text('Create a plan on the Plan tab first.'), findsOneWidget);
  });

  testWidgets(
    'Recording lists started sessions, newest first, not future ones',
    (tester) async {
      final d = await _withQuiz();
      addTearDown(d.tasks.dispose);
      await d.plans!.acceptPlan(
        [
          _session('mon', DateTime(2026, 10, 12, 20)),
          _session('wed', DateTime(2026, 10, 14, 10)),
          _session('thu', DateTime(2026, 10, 15, 20)),
        ],
        from: DateTime(2026, 10, 12),
        to: DateTime(2026, 10, 19),
      );
      await tester.pumpWidget(MyApp(dependencies: d));
      await tester.pumpAndSettle();
      await _openSheet(tester);
      await tapVisible(tester, find.byKey(const ValueKey('quick-add-session')));
      expect(find.text('Which session?'), findsOneWidget);
      final wed = tester.getTopLeft(
        find.byKey(const ValueKey('record-pick-wed')),
      );
      final mon = tester.getTopLeft(
        find.byKey(const ValueKey('record-pick-mon')),
      );
      expect(wed.dy, lessThan(mon.dy));
      expect(find.byKey(const ValueKey('record-pick-thu')), findsNothing);

      await tapVisible(tester, find.byKey(const ValueKey('record-pick-wed')));
      await tapVisible(tester, find.byKey(const ValueKey('record-completed')));
      await tapVisible(tester, find.byKey(const ValueKey('record-save')));
      expect(
        d.plans!.savedSessions.singleWhere((s) => s.id == 'wed').status,
        SessionStatus.completed,
      );
    },
  );

  testWidgets('In the demo, recording is shown but disabled', (tester) async {
    final d = AppDependencies.demo();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await _openSheet(tester);
    expect(find.text('Not available in the demo'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.byKey(const ValueKey('quick-add-session')),
    );
    expect(tile.enabled, isFalse);
  });
}
