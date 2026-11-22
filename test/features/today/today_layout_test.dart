import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/study_session.dart';

import '../../support/test_apps.dart';

void main() {
  testWidgets('Today shows the next session once, with "Record session"', (
    tester,
  ) async {
    final d = await realModeApp(courses: 1);
    addTearDown(d.tasks.dispose);
    await d.tasks.add(
      AcademicTask(
        id: 'quiz',
        title: 'Quiz 1',
        subject: 'DES3111 · Course 1',
        description: '',
        deadline: DateTime(2026, 10, 16, 23, 59),
        estimatedMinutes: 60,
        courseId: 'c1',
      ),
    );
    await d.plans!.acceptPlan(
      [
        StudySession(
          id: 'pm',
          taskId: 'quiz',
          title: 'Quiz 1',
          subject: 'DES3111 · Course 1',
          startsAt: DateTime(2026, 10, 14, 20),
          minutes: 60,
        ),
      ],
      from: DateTime(2026, 10, 14),
      to: DateTime(2026, 10, 21),
    );
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(find.text('Next study session · your plan'), findsOneWidget);
    expect(find.text('Record session'), findsOneWidget);
    // The card already shows the task that is due next.
    expect(find.text('Next deadline'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('1 study session · 1h planned'), findsOneWidget);
    // …and "Your day" does not list that session a second time.
    expect(find.textContaining('tap to record'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
