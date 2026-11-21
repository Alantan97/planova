import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/models/onboarding_progress.dart';

import '../../support/test_apps.dart';

const _atStep = OnboardingProgress(accountType: AccountType.guest);

void main() {
  testWidgets('Intro cards use a large icon', (tester) async {
    final d = await realModeApp(progress: _atStep.copyWith(step: 1));
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    final icon = tester.widget<Icon>(find.byIcon(Icons.upload_file_outlined));
    expect(icon.size, 56);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip looks secondary; Continue stays the main button', (
    tester,
  ) async {
    final d = await realModeApp(progress: _atStep.copyWith(step: 2));
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('onboarding-next'));
    expect(tester.widget(next), isA<OutlinedButton>());
    expect(find.text('Skip'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-name')),
      'Sam',
    );
    await tester.pump();
    expect(tester.widget(next), isA<FilledButton>());
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Character counters appear only near the limit', (tester) async {
    final d = await realModeApp(progress: _atStep.copyWith(step: 2));
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('onboarding-name'));
    await tester.enterText(field, 'Sam');
    await tester.pump();
    expect(find.text('3/40'), findsNothing);
    await tester.enterText(field, 'A' * 33);
    await tester.pump();
    expect(find.text('33/40'), findsOneWidget);
  });
}
