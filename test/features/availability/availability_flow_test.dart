import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';

import '../../support/widget_actions.dart';

Future<void> openAvailability(WidgetTester tester) async {
  await tester.tap(find.text('Plan'));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const ValueKey('open-availability')));
  expect(find.text('Your normal week.'), findsOneWidget);
}

/// The summary panel sits at the top of a lazy list, so scroll up to it.
Future<void> expectFreeTime(WidgetTester tester, String amount) async {
  final finder = find.text('$amount free for study each week');
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      -300,
      scrollable: find.byType(Scrollable).last,
    );
  }
  expect(finder, findsOneWidget);
}

Future<void> chooseDays(WidgetTester tester, List<int> days) async {
  for (final day in days) {
    await tapVisible(tester, find.byKey(ValueKey('weekday-$day')));
  }
}

void main() {
  testWidgets(
    'Add, edit and delete study windows and commitments from the Plan tab',
    (tester) async {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.tasks.dispose);
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await openAvailability(tester);
      expect(find.text('No study time yet'), findsOneWidget);

      // A study window needs at least one day.
      await tapVisible(tester, find.byKey(const ValueKey('add-study-window')));
      await tapVisible(tester, find.byKey(const ValueKey('save-time-block')));
      expect(find.text('Choose at least one day.'), findsOneWidget);

      // Default window is 20:00–22:00; Mon + Wed = 4h a week.
      await chooseDays(tester, [1, 3]);
      await tapVisible(tester, find.byKey(const ValueKey('save-time-block')));
      expect(find.text('Mon, Wed · 20:00–22:00'), findsOneWidget);
      await expectFreeTime(tester, '4h');

      // A commitment outside every study window does not change free time.
      await tapVisible(tester, find.byKey(const ValueKey('add-commitment')));
      await tapVisible(tester, find.byKey(const ValueKey('save-time-block')));
      expect(find.text('Enter a name.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('commitment-title')),
        'Futsal club',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('commitment-category')),
      );
      await tester.tap(find.text('Club / society').last);
      await tester.pumpAndSettle();
      await chooseDays(tester, [3]);
      await tapVisible(tester, find.byKey(const ValueKey('save-time-block')));
      expect(find.text('Futsal club'), findsOneWidget);
      expect(find.text('Club / society · Wed · 08:00–10:00'), findsOneWidget);
      await expectFreeTime(tester, '4h');

      // Edit the window to start at 08:00 on Wednesday only: the 08:00–10:00
      // club now overlaps and is removed from free time.
      await tapVisible(
        tester,
        find.byTooltip('Options for Mon, Wed · 20:00–22:00'),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit study window'), findsOneWidget);
      await chooseDays(tester, [1]); // Deselect Monday.
      await tapVisible(tester, find.byKey(const ValueKey('start-time')));
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '08');
      await tester.enterText(fields.at(1), '00');
      await tester.tap(find.text('AM')); // Test locale uses a 12-hour picker.
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Starts: 08:00'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('save-time-block')));
      expect(find.text('Wed · 08:00–22:00'), findsOneWidget);
      await expectFreeTime(tester, '12h');
      await tapVisible(tester, find.text('Free time by day'));
      expect(find.text('10:00–22:00'), findsOneWidget);

      // Delete the commitment after confirming.
      await tapVisible(tester, find.byTooltip('Options for Futsal club'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Futsal club'), findsNothing);
      await expectFreeTime(tester, '14h');

      // The Plan tab summary reflects the saved week.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('1 study window · 0 commitments · 14h free each week'),
        findsOneWidget,
      );
      expect(find.text('Edit availability'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Availability screens fit a small phone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final dependencies = AppDependencies.demo();
    addTearDown(dependencies.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await openAvailability(tester);
    await tapVisible(tester, find.byKey(const ValueKey('add-commitment')));
    await chooseDays(tester, [1, 2, 3, 4, 5, 6, 7]);
    expect(tester.takeException(), isNull);
  });
}
