import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/models/onboarding_progress.dart';

import '../../support/test_apps.dart';
import '../../support/widget_actions.dart';

void main() {
  testWidgets('Profile shows account, semester, week, rules and honest note', (
    tester,
  ) async {
    final d = await realModeApp(
      courses: 2,
      progress: const OnboardingProgress(
        completed: true,
        displayName: 'Sam',
        accountType: AccountType.guest,
      ),
    );
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Guest · saved on this device'), findsOneWidget);
    expect(find.text('Semester 1'), findsOneWidget);
    expect(find.textContaining('2 courses'), findsOneWidget);
    await tester.ensureVisible(find.text('Weekly availability'));
    expect(find.text('Set availability'), findsOneWidget);
    await tester.ensureVisible(find.text('Sessions of 30–60 min'));
    expect(find.text('15 min break between sessions'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('not trained AI'));
    expect(find.textContaining('not trained AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The name can be changed and cleared from Profile', (
    tester,
  ) async {
    final d = await realModeApp();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Add your name'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('edit-name')));
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      ' Aina ',
    );
    await tapVisible(tester, find.byKey(const ValueKey('save-name')));
    expect(find.text('Aina'), findsOneWidget);
    expect(d.profile.progress.displayName, 'Aina');

    await tapVisible(tester, find.byKey(const ValueKey('edit-name')));
    await tester.enterText(find.byKey(const ValueKey('profile-name')), '');
    await tapVisible(tester, find.byKey(const ValueKey('save-name')));
    expect(find.text('Add your name'), findsOneWidget);
    expect(d.profile.progress.displayName, isNull);
  });

  testWidgets('Profile fits a small phone with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final d = await realModeApp(courses: 1);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
