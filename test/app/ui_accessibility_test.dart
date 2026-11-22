import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';

void main() {
  testWidgets(
    'Main tabs meet Android touch-target, label and contrast guidelines',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final dependencies = AppDependencies.demo();
        addTearDown(dependencies.close);
        await tester.pumpWidget(MyApp(dependencies: dependencies));
        await tester.pumpAndSettle();
        for (final tab in ['Today', 'Plan', 'Courses', 'Profile']) {
          await tester.tap(find.byKey(ValueKey('nav-${tab.toLowerCase()}')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: tab);
          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
            reason: tab,
          );
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
            reason: tab,
          );
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
            reason: tab,
          );
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'Main tabs and empty tasks fit a small phone with double-size text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      for (final tab in ['Today', 'Plan', 'Courses', 'Profile']) {
        await tester.tap(find.byKey(ValueKey('nav-${tab.toLowerCase()}')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
      for (final task in dependencies.tasks.tasks.toList()) {
        await dependencies.tasks.delete(task.id);
      }
      await tester.tap(find.byKey(const ValueKey('nav-courses')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.textContaining('A fresh start.'), findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
