import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';

void main() {
  testWidgets('Startup waits for storage and then shows tasks', (tester) async {
    final completer = Completer<AppDependencies>();
    await tester.pumpWidget(MyApp(loadDependencies: () => completer.future));
    expect(find.text('Opening Planova…'), findsOneWidget);
    expect(find.text('Tasks'), findsNothing);
    completer.complete(AppDependencies.demo());
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Storage failure offers retry rather than silently replacing data',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MyApp(
          loadDependencies: () async {
            if (attempts++ == 0) {
              throw const FormatException('Unsupported storage version');
            }
            return AppDependencies.demo();
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not open saved tasks'), findsOneWidget);
      expect(find.text('Tasks'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Tasks'), findsOneWidget);
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
