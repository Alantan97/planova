import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/data/local/local_profile_repository.dart';
import 'package:planova/data/local/local_task_repository.dart';
import 'package:planova/data/repositories/profile_repository.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/onboarding_progress.dart';
import 'package:sembast/sembast_memory.dart';

import '../../support/test_apps.dart';
import '../../support/widget_actions.dart';

void main() {
  test('Erasing deletes every saved Planova record', () async {
    final factory = newDatabaseFactoryMemory();
    var database = await factory.openDatabase('planova.db');
    final tasks = await LocalTaskRepository.open(database);
    await tasks.saveSemester(
      AcademicSemester(
        id: 's1',
        name: 'Semester 1',
        startDate: DateTime(2026, 10),
        endDate: DateTime(2027, 2),
      ),
      isNew: true,
    );
    final profile = await LocalProfileRepository.open(
      database,
      hasExistingData: true,
    );
    await profile.save(
      profile.progress.copyWith(displayName: 'Aina', completed: true),
    );
    await profile.close();
    await tasks.close();

    database = await factory.openDatabase('planova.db');
    await AppDependencies.eraseLocalData(database);
    await database.close();

    database = await factory.openDatabase('planova.db');
    final reopened = await LocalTaskRepository.open(database);
    final fresh = await LocalProfileRepository.open(
      database,
      hasExistingData: false,
    );
    expect(reopened.semesters, isEmpty);
    expect(fresh.progress.displayName, isNull);
    expect(fresh.progress.completed, isFalse);
    await fresh.close();
    await reopened.close();
  });

  testWidgets('Clear all data wipes storage and restarts at the welcome', (
    tester,
  ) async {
    var loads = 0;
    var erased = 0;
    final opened = <AppDependencies>[];
    Future<AppDependencies> load() async {
      loads++;
      final d = await realModeApp();
      final app = AppDependencies(
        tasks: d.tasks,
        study: d.study,
        clock: d.clock,
        availability: d.availability,
        plans: d.plans,
        // The first launch is a finished student; after the wipe, a new one.
        profile: MemoryProfileRepository(
          OnboardingProgress(
            completed: loads == 1,
            accountType: loads == 1 ? AccountType.guest : AccountType.none,
          ),
        ),
        eraseStorage: () async => erased++,
      );
      opened.add(app);
      return app;
    }

    await tester.pumpWidget(MyApp(loadDependencies: load));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();

    // Cancel keeps everything.
    await tapVisible(tester, find.byKey(const ValueKey('clear-data')));
    expect(find.text('Clear all data?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(erased, 0);

    await tapVisible(tester, find.byKey(const ValueKey('clear-data')));
    await tester.tap(find.byKey(const ValueKey('confirm-clear-data')));
    await tester.pumpAndSettle();
    expect(erased, 1);
    expect(loads, 2);
    expect(opened.last.profile.progress.completed, isFalse);
    expect(find.byKey(const ValueKey('nav-profile')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('The button is hidden when the app does not own storage', (
    tester,
  ) async {
    final d = await realModeApp();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clear-data')), findsNothing);
    expect(find.text('Developer'), findsNothing);
  });
}
