import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/data/local/local_profile_repository.dart';
import 'package:planova/models/onboarding_progress.dart';

import '../../support/test_apps.dart';
import '../../support/widget_actions.dart';

void main() {
  testWidgets('Ranking stays hidden until experimental features are on', (
    tester,
  ) async {
    final d = await realModeApp(courses: 1);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-courses')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-task-ranking')), findsNothing);
    expect(find.byKey(const ValueKey('tasks-import-proforma')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('experimental-switch')));
    expect(d.profile.progress.showExperimental, isTrue);

    await tester.tap(find.byKey(const ValueKey('nav-courses')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-task-ranking')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('The switch is saved; older profiles start with it off', () {
    const on = OnboardingProgress(
      completed: true,
      accountType: AccountType.guest,
      showExperimental: true,
    );
    final map = ProfileCodec.encode(on);
    expect(ProfileCodec.decode(map).showExperimental, isTrue);
    final old = Map<String, Object?>.of(map)..remove('showExperimental');
    expect(ProfileCodec.decode(old).showExperimental, isFalse);
    final broken = Map<String, Object?>.of(map)..['showExperimental'] = 'yes';
    expect(() => ProfileCodec.decode(broken), throwsFormatException);
  });
}
