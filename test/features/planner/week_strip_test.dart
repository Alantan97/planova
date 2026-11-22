import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/planova_app.dart';

import '../../support/test_apps.dart';

void main() {
  testWidgets('All seven days fit on a 375 px phone, each 48 px wide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = await realModeApp(courses: 1);
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-plan')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      final rect = tester.getRect(find.byKey(ValueKey('day-$i')));
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(375));
    }
    await tester.tap(find.byKey(const ValueKey('day-6')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sun, 18 October'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
