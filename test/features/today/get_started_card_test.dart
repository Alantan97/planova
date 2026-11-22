import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/models/onboarding_progress.dart';

import '../../support/test_apps.dart';
import '../../support/widget_actions.dart';

const _done = OnboardingProgress(
  completed: true,
  step: 8,
  accountType: AccountType.guest,
);

void main() {
  testWidgets('Each step opens its own screen', (tester) async {
    final d = await realModeApp(semesters: 0, progress: _done);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(find.text('GET STARTED · 0 OF 3 DONE'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('setup-semester')));
    expect(find.text('Your courses.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('setup-availability')));
    expect(find.text('Your normal week.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continue setup reopens the guide at the first unfinished step', (
    tester,
  ) async {
    // A semester exists, so the next step is courses (journey step 4),
    // even though the journey itself was finished earlier.
    final d = await realModeApp(progress: _done);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    expect(find.text('GET STARTED · 1 OF 3 DONE'), findsOneWidget);
    expect(find.text('Continue setup'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('setup-continue')));
    expect(d.profile.progress.completed, isFalse);
    expect(d.profile.progress.step, 4);
    expect(find.textContaining('STEP 3 OF 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
