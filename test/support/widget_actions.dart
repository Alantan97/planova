import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable && widget.restorationId != 'editable',
          )
          .last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Fills an EffortField (hours + minutes boxes) identified by its fieldKey.
Future<void> enterEffort(
  WidgetTester tester,
  String fieldKey, {
  String hours = '',
  String minutes = '',
}) async {
  await tester.enterText(find.byKey(ValueKey('$fieldKey-hours')), hours);
  await tester.enterText(find.byKey(ValueKey('$fieldKey-minutes')), minutes);
  await tester.pump();
}
