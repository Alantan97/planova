import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/models/academic_task.dart';

import '../../support/test_apps.dart';

void main() {
  testWidgets('This week on Plan counts tasks in plain words', (tester) async {
    final d = await realModeApp();
    addTearDown(d.tasks.dispose);
    await d.tasks.add(
      AcademicTask(
        id: 'quiz',
        title: 'Quiz 1',
        subject: 'DES3113',
        description: '',
        deadline: DateTime(2026, 10, 16, 23, 59),
        estimatedMinutes: 60,
      ),
    );
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-plan')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('0 of 1 task completed'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 1 task completed'), findsOneWidget);
    expect(find.text('Make space to reflect'), findsNothing);
  });
}
