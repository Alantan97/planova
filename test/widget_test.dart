import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/main.dart';

void main() {
  testWidgets('Today shows branding and opens sample session details', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('planova'), findsNothing);
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('Make room for progress.'), findsOneWidget);
    expect(find.bySemanticsLabel('Planova logo'), findsOneWidget);
    await tester.ensureVisible(find.text('View session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View session'));
    await tester.pumpAndSettle();
    expect(find.text('SAMPLE SESSION'), findsOneWidget);
    expect(find.textContaining('No study time'), findsOneWidget);
    await tester.tap(find.text('Back to schedule'));
    await tester.pumpAndSettle();
    expect(find.text('SAMPLE SESSION'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Plan browses days and weeks and excludes lectures from study time',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(find.text('105 min of study'), findsOneWidget);
      expect(find.text('Database lecture'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('day-3')));
      await tester.pumpAndSettle();
      expect(find.text('60 min of study'), findsOneWidget);
      expect(find.text('Outline the project report'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('day-5')));
      await tester.pumpAndSettle();
      expect(find.text('0 min of study'), findsOneWidget);
      expect(find.text('A little breathing room.'), findsOneWidget);
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(find.text('19–25 October 2026'), findsOneWidget);
      expect(find.text('0 min of study'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous week'));
      await tester.tap(find.byKey(const ValueKey('day-2')));
      await tester.pumpAndSettle();
      expect(find.text('105 min of study'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Today and Plan fit a small phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('day-5')));
    await tester.tap(find.byKey(const ValueKey('day-5')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('A little breathing room.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final tab in ['Tasks', 'Progress']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Calendar selection survives switching tabs', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('60 min of study'), findsOneWidget);
    expect(find.text('Outline the project report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tasks opens sample details and Progress shows shared totals', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('4 active · 1 completed'), findsOneWidget);
    await tester.tap(find.text('Database assignment'));
    await tester.pumpAndSettle();
    expect(find.text('SAMPLE TASK'), findsOneWidget);
    expect(find.textContaining('25% complete'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 5 tasks completed'), findsOneWidget);
    expect(find.textContaining('3h 30m', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
