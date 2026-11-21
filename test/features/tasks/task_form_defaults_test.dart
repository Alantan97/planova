import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/planova_app.dart';

import '../../support/test_apps.dart';
import '../../support/widget_actions.dart';

void main() {
  testWidgets('New task defaults to the only course; date can be removed', (
    tester,
  ) async {
    final d = await realModeApp(courses: 1);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('today-add-task')));
    expect(find.textContaining('DES3111 · Course 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-subject')), findsNothing);
    expect(find.text('Remove due date'), findsOneWidget);
    expect(find.text('No due date yet'), findsNothing);
  });

  testWidgets('With several courses the student chooses', (tester) async {
    final d = await realModeApp(courses: 2);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('today-add-task')));
    expect(find.byKey(const ValueKey('task-subject')), findsOneWidget);
  });
}
