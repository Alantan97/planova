import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/onboarding_progress.dart';
import 'package:planova/models/study_preferences.dart';
import 'package:planova/models/weekly_availability.dart';

import '../../support/test_apps.dart';
import '../../support/widget_actions.dart';

/// Real-mode app with one dated task and every evening free (preview clock:
/// Wednesday 14 October 2026, 13:00).
Future<AppDependencies> _app({StudyPreferences? preferences}) async {
  final d = await realModeApp(
    progress: OnboardingProgress(
      completed: true,
      accountType: AccountType.guest,
      preferences: preferences ?? const StudyPreferences(),
    ),
  );
  await d.tasks.add(
    AcademicTask(
      id: 'quiz',
      title: 'Quiz 1',
      subject: 'DES3111',
      description: '',
      deadline: DateTime(2026, 10, 18, 23, 59),
      estimatedMinutes: 60,
    ),
  );
  await d.availability.saveWindow(
    StudyWindow(
      id: 'w',
      range: WeeklyTimeRange(
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        startMinute: 20 * 60,
        endMinute: 22 * 60,
      ),
    ),
  );
  return d;
}

Future<void> _openPreferences(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-profile')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const ValueKey('open-preferences')));
}

void main() {
  testWidgets('Change, save and see study preferences on Profile', (
    tester,
  ) async {
    final d = await _app();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await _openPreferences(tester);
    expect(find.text('Study preferences'), findsOneWidget);

    // A longest session shorter than the shortest cannot be picked.
    await tapVisible(tester, find.byKey(const ValueKey('pref-min-45')));
    final tooShort = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('pref-max-30')),
    );
    expect(tooShort.onSelected, isNull);

    await tapVisible(tester, find.byKey(const ValueKey('pref-max-90')));
    await tapVisible(tester, find.byKey(const ValueKey('pref-break-0')));
    await tapVisible(tester, find.byKey(const ValueKey('pref-off-6')));
    await tapVisible(tester, find.byKey(const ValueKey('pref-off-7')));
    await tapVisible(tester, find.byKey(const ValueKey('save-preferences')));

    expect(
      d.profile.progress.preferences,
      const StudyPreferences(
        minSessionMinutes: 45,
        maxSessionMinutes: 90,
        breakMinutes: 0,
        daysOff: {6, 7},
      ),
    );
    expect(find.textContaining('next plan or re-plan'), findsOneWidget);
    await tester.ensureVisible(find.text('Sessions of 45m–1h 30m'));
    expect(find.text('No break between sessions'), findsOneWidget);
    expect(find.text('Days off: Sat, Sun'), findsOneWidget);

    // Reset brings back the usual rules (after the "Saved" message clears).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('open-preferences')));
    await tapVisible(tester, find.byKey(const ValueKey('reset-preferences')));
    await tapVisible(tester, find.byKey(const ValueKey('save-preferences')));
    expect(d.profile.progress.preferences, const StudyPreferences());
    expect(tester.takeException(), isNull);
  });

  testWidgets('At least one study day stays selectable', (tester) async {
    final d = await _app(
      preferences: const StudyPreferences(daysOff: {1, 2, 3, 4, 5, 6}),
    );
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await _openPreferences(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pref-off-7')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    final sunday = tester.widget<FilterChip>(
      find.byKey(const ValueKey('pref-off-7')),
    );
    expect(sunday.onSelected, isNull);
  });

  testWidgets('Create my plan follows the saved days off', (tester) async {
    // Wednesday (today) and Thursday are days off, so the first session is
    // on Friday evening.
    final d = await _app(preferences: const StudyPreferences(daysOff: {3, 4}));
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-plan')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('create-plan')));
    await tapVisible(tester, find.byKey(const ValueKey('proposal-accept')));
    expect(d.plans!.savedSessions.single.startsAt, DateTime(2026, 10, 16, 20));
  });

  testWidgets('Preferences fit a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final d = await _app();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await _openPreferences(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
