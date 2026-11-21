import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/core/theme/app_theme.dart';
import 'package:planova/features/courses/screens/academic_record_form.dart';

import '../../support/test_apps.dart';
import '../../support/widget_actions.dart';

void main() {
  testWidgets('Adding a course skips the semester picker with one semester', (
    tester,
  ) async {
    final one = await realModeApp();
    addTearDown(one.tasks.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPlanovaTheme(),
        home: AcademicRecordForm(
          repository: one.tasks,
          clock: one.clock,
          semesterId: 's1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('course-semester')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('course-code')),
      'des3113',
    );
    await tester.enterText(
      find.byKey(const ValueKey('academic-name')),
      'Mobile',
    );
    await tapVisible(tester, find.text('Save course'));
    expect(one.tasks.courses.single.semesterId, 's1');

    final two = await realModeApp(semesters: 2);
    addTearDown(two.tasks.dispose);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: buildPlanovaTheme(),
        home: AcademicRecordForm(
          repository: two.tasks,
          clock: two.clock,
          semesterId: 's2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('course-semester')), findsOneWidget);
  });
}
