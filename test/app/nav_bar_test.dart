import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/app/widgets/planova_nav_bar.dart';

import '../support/test_apps.dart';

void main() {
  testWidgets(
    'Pill tabs with a sliding highlight and a separate + on the right',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final d = await realModeApp();
      addTearDown(d.tasks.dispose);
      await tester.pumpWidget(MyApp(dependencies: d));
      await tester.pumpAndSettle();

      // The + has no visible label but is announced as "Add", and sits to
      // the right of the last tab.
      expect(find.text('Add'), findsNothing);
      expect(find.bySemanticsLabel('Add'), findsOneWidget);
      final plus = tester.getRect(find.byKey(const ValueKey('quick-add')));
      final profile = tester.getRect(find.byKey(const ValueKey('nav-profile')));
      expect(plus.left, greaterThan(profile.right));
      expect(plus.right, lessThanOrEqualTo(375));

      double highlightLeft() => tester
          .getTopLeft(
            find.descendant(
              of: find.byType(PlanovaNavBar),
              matching: find.byType(AnimatedPositioned),
            ),
          )
          .dx;
      // Tapping draws no ripple or pressed shade on the tab itself; only
      // the sliding highlight marks the selection.
      final tab = tester.widget<InkWell>(
        find.byKey(const ValueKey('nav-courses')),
      );
      expect(tab.splashFactory, NoSplash.splashFactory);
      for (final state in [WidgetState.pressed, WidgetState.hovered]) {
        expect(tab.overlayColor!.resolve({state}), Colors.transparent);
      }

      final start = highlightLeft();
      await tester.tap(find.byKey(const ValueKey('nav-courses')));
      await tester.pump(); // rebuild starts the slide
      await tester.pump(const Duration(milliseconds: 100));
      final midway = highlightLeft();
      await tester.pumpAndSettle();
      final end = highlightLeft();
      expect(midway, greaterThan(start), reason: 'highlight is moving');
      expect(end, greaterThan(midway), reason: 'and finishes on Courses');
      expect(
        tester.widget<PlanovaNavBar>(find.byType(PlanovaNavBar)).selectedIndex,
        2,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
