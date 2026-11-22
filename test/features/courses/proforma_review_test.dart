import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/core/widgets/experimental_features.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/core/theme/app_theme.dart';
import 'package:planova/features/courses/screens/proforma_import_screen.dart';
import 'package:planova/features/courses/screens/courses_screen.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/proforma.dart';
import 'package:planova/services/proforma/proforma_import_service.dart';

import '../../support/proforma_fixtures.dart';
import '../../support/widget_actions.dart';

Future<void> mountImporter(
  WidgetTester tester,
  AppDependencies dependencies,
  Future<ProformaDraft?> Function() loader, {
  bool experimental = true,
}) async {
  await dependencies.tasks.saveSemester(
    AcademicSemester(
      id: 's',
      name: 'Semester 1',
      startDate: DateTime(2026, 10),
      endDate: DateTime(2027, 2),
    ),
    isNew: true,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildPlanovaTheme(),
      // Weekly learning is an experimental feature; most tests here cover it.
      builder: (context, child) =>
          ExperimentalFeatures(enabled: experimental, child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProformaImportScreen(
                  repository: dependencies.tasks,
                  clock: dependencies.clock,
                  semesterId: 's',
                  loadDocument: loader,
                ),
              ),
            ),
            child: const Text('Open importer'),
          ),
        ),
      ),
    ),
  );
  await tapVisible(tester, find.text('Open importer'));
}

/// Assessments start selected; untick the given rows.
Future<void> untick(WidgetTester tester, Iterable<int> rows) async {
  for (final i in rows) {
    await tapVisible(tester, find.byKey(ValueKey('import-select-$i')));
  }
}

void main() {
  Future<ProformaDraft> draft() =>
      ProformaImportService(
        reader: FakeTextReader([coursePage, assessmentPage]),
      ).extract(
        Uint8List.fromList(utf8.encode('%PDF-1.7 example')),
        fileName: 'example.pdf',
      );

  testWidgets('Weekly preview shows source hours and returns without saving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final dependencies = AppDependencies.demo();
    addTearDown(dependencies.close);
    final original = await draft();
    final withWeekly = ProformaDraft(
      courseCode: original.courseCode,
      courseName: original.courseName,
      documentSession: original.documentSession,
      courseSource: original.courseSource,
      assessments: original.assessments,
      warnings: original.warnings,
      weeklyLearning: [
        WeeklyLearningDraft(
          weekStart: 3,
          weekEnd: 4,
          topic: 'Structured programming and practice',
          guidedNf2fHours: null,
          independentNf2fHours: 2,
          onlineHours: const [null, 1, 0, null],
          totalSltHours: 5,
          source: const ProformaSource(
            fingerprint: 'weekly',
            fileName: 'example.pdf',
            page: 4,
            rowId: 'weekly-4-1',
            excerpt: 'Printed weekly row',
          ),
        ),
      ],
    );
    await mountImporter(tester, dependencies, () async => withWeekly);
    await tapVisible(tester, find.text('Choose PDF'));
    await tapVisible(tester, find.text('View weekly learning (1)'));
    expect(find.text('Weekly learning'), findsOneWidget);
    expect(find.text('Use reviewed entries'), findsOneWidget);
    await tapVisible(tester, find.text('Weeks 3–4'));
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('0 h'), findsNWidgets(3));
    expect(
      find.text(
        'Hours cover this entire week range. Do not multiply them by the number of weeks.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('Source · page 4'));
    expect(find.text('Printed weekly row'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(dependencies.tasks.courses, isEmpty);
    expect(dependencies.tasks.tasks.length, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('With experimental features off, weekly learning is saved '
      'but not shown', (tester) async {
    final dependencies = AppDependencies.demo();
    addTearDown(dependencies.close);
    final original = await draft();
    final withWeekly = ProformaDraft(
      courseCode: original.courseCode,
      courseName: original.courseName,
      documentSession: original.documentSession,
      courseSource: original.courseSource,
      assessments: original.assessments,
      warnings: original.warnings,
      weeklyLearning: [
        WeeklyLearningDraft(
          weekStart: 6,
          weekEnd: 6,
          topic: 'Hidden topic',
          guidedNf2fHours: 1,
          independentNf2fHours: 2,
          onlineHours: const [null, 1, 0, null],
          totalSltHours: 5,
          source: ProformaSource(
            fingerprint: original.courseSource.fingerprint,
            fileName: 'example.pdf',
            page: 4,
            rowId: 'weekly-4-1',
            excerpt: 'Hidden topic row',
          ),
        ),
      ],
    );
    await mountImporter(
      tester,
      dependencies,
      () async => withWeekly,
      experimental: false,
    );
    await tapVisible(tester, find.text('Choose PDF'));
    expect(find.textContaining('View weekly learning'), findsNothing);
    await tapVisible(tester, find.text('Continue to assessments'));
    await untick(tester, [0, 1, 2, 3, 4]);
    await tapVisible(tester, find.text('Review import'));
    expect(find.textContaining('weekly entries'), findsNothing);
    await tapVisible(
      tester,
      find.text('I reviewed the course and selected assessments.'),
    );
    await tapVisible(tester, find.text('Save reviewed import'));
    final saved = dependencies.tasks.courses.single.weeklyLearning.single;
    expect(saved.confirmed.topic, 'Hidden topic');
  });

  testWidgets(
    'Review weekly corrections, import them, then edit the saved course',
    (tester) async {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      final original = await draft();
      final printed = WeeklyLearningDraft(
        weekStart: 6,
        weekEnd: 6,
        topic: 'Original topic',
        guidedNf2fHours: null,
        independentNf2fHours: 2,
        onlineHours: const [null, 1, 0, null],
        totalSltHours: 5,
        source: ProformaSource(
          fingerprint: original.courseSource.fingerprint,
          fileName: 'example.pdf',
          page: 4,
          rowId: 'weekly-4-1',
          excerpt: 'Original topic and printed hours',
        ),
      );
      final withWeekly = ProformaDraft(
        courseCode: original.courseCode,
        courseName: original.courseName,
        documentSession: original.documentSession,
        courseSource: original.courseSource,
        assessments: original.assessments,
        warnings: original.warnings,
        weeklyLearning: [printed],
      );
      await mountImporter(tester, dependencies, () async => withWeekly);
      await tapVisible(tester, find.text('Choose PDF'));
      await tapVisible(tester, find.text('View weekly learning (1)'));
      await tapVisible(tester, find.text('Week 6'));
      await tapVisible(tester, find.text('Edit entry'));
      await tester.enterText(find.byKey(const ValueKey('weekly-start')), '7');
      await tester.enterText(find.byKey(const ValueKey('weekly-end')), '7');
      await tester.enterText(
        find.byKey(const ValueKey('weekly-topic')),
        'Reviewed topic',
      );
      await tester.enterText(
        find.byKey(const ValueKey('weekly-hours-0')),
        '-1',
      );
      await tapVisible(tester, find.text('Use changes'));
      expect(
        find.text('Enter a non-negative number of hours.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('weekly-hours-0')),
        '0.5',
      );
      await tapVisible(tester, find.text('Use changes'));
      expect(find.text('Week 7'), findsOneWidget);
      await tapVisible(tester, find.text('Use reviewed entries'));
      expect(dependencies.tasks.courses, isEmpty);
      await tapVisible(tester, find.text('Continue to assessments'));
      await untick(tester, [0, 1, 2, 3, 4]);
      await tapVisible(tester, find.text('Review import'));
      await tapVisible(
        tester,
        find.text(
          'I reviewed the course, weekly learning and selected assessments.',
        ),
      );
      await tapVisible(tester, find.text('Save reviewed import'));
      final record = dependencies.tasks.courses.single.weeklyLearning.single;
      expect(record.printed.weekStart, 6);
      expect(record.confirmed.weekStart, 7);
      expect(record.printed.guidedNf2fHours, isNull);
      expect(record.confirmed.guidedNf2fHours, 0.5);
      expect(record.printed.topic, 'Original topic');
      expect(record.confirmed.topic, 'Reviewed topic');
      expect(dependencies.tasks.tasks.length, 5);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPlanovaTheme(),
          builder: (context, child) =>
              ExperimentalFeatures(enabled: true, child: child!),
          home: CoursesScreen(
            repository: dependencies.tasks,
            clock: dependencies.clock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Weekly learning (1)'));
      await tapVisible(tester, find.text('Week 7'));
      await tapVisible(tester, find.text('Edit entry'));
      await tester.enterText(
        find.byKey(const ValueKey('weekly-topic')),
        'Saved course correction',
      );
      await tapVisible(tester, find.text('Use changes'));
      await tapVisible(tester, find.text('Save changes'));
      expect(
        dependencies.tasks.courses.single.weeklyLearning.single.confirmed.topic,
        'Saved course correction',
      );
      expect(
        dependencies.tasks.courses.single.weeklyLearning.single.printed.topic,
        'Original topic',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Printed SLT hours prefill effort; a due date can be left for later',
    (tester) async {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      final original = await draft();
      final suggested = ProformaDraft(
        courseCode: original.courseCode,
        courseName: original.courseName,
        documentSession: original.documentSession,
        courseSource: original.courseSource,
        assessments: [
          AssessmentDraft(
            title: original.assessments.first.title,
            source: original.assessments.first.source,
            sltHours: 8,
          ),
        ],
        warnings: original.warnings,
      );
      await mountImporter(tester, dependencies, () async => suggested);
      await tapVisible(tester, find.text('Choose PDF'));
      await tapVisible(tester, find.text('Continue to assessments'));
      final hours = tester.widget<TextField>(
        find.byKey(const ValueKey('import-minutes-0-hours')),
      );
      expect(hours.controller!.text, '8');
      expect(
        find.textContaining('Suggested from the proforma: 8h'),
        findsOneWidget,
      );
      expect(find.text('Add due date (optional)'), findsOneWidget);
      await tapVisible(tester, find.text('Review import'));
      expect(
        find.text('1 without a due date yet · add them later'),
        findsOneWidget,
      );
      expect(find.text('No due date yet · add it later'), findsOneWidget);
      await tapVisible(
        tester,
        find.text('I reviewed the course and selected assessments.'),
      );
      await tapVisible(tester, find.text('Save reviewed import'));
      final task = dependencies.tasks.tasks.last;
      expect(task.deadline, isNull);
      expect(task.estimatedMinutes, 480);
      final ranked = await tester.runAsync(
        () => dependencies.ranking.rank(
          dependencies.tasks.tasks,
          dependencies.clock.now(),
        ),
      );
      final waiting = ranked!.unranked.where((u) => u.task.id == task.id);
      expect(waiting.single.reason, 'No due date yet. Add it in Edit task.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Import review fits a small screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final dependencies = AppDependencies.demo();
    addTearDown(dependencies.close);
    await mountImporter(tester, dependencies, draft);
    await tapVisible(tester, find.text('Choose PDF'));
    await tapVisible(tester, find.text('Source · page 1'));
    expect(find.byType(SelectableText), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('Continue to assessments'));
    await tapVisible(tester, find.byKey(const ValueKey('import-date-0')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Review requires effort and confirmation before saving; reimport keeps tasks',
    (tester) async {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      await mountImporter(tester, dependencies, draft);
      await tapVisible(tester, find.text('Choose PDF'));
      expect(dependencies.tasks.courses, isEmpty);
      await tapVisible(tester, find.text('Continue to assessments'));
      await untick(tester, [1, 2, 3, 4]);
      // Without a printed SLT value there is no suggestion: effort is needed.
      await tapVisible(tester, find.text('Review import'));
      expect(find.text('STEP 2 OF 3 · NOTHING SAVED YET'), findsOneWidget);
      expect(
        find.text(
          'Each selected assessment needs a title and a time estimate.',
        ),
        findsOneWidget,
      );
      expect(dependencies.tasks.tasks.length, 5);
      expect(dependencies.tasks.courses, isEmpty);
      // Unticking scrolled down the list; scroll back up to the first row.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('import-edit-0')),
        -300,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('import-assessment-step')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tapVisible(tester, find.byKey(const ValueKey('import-edit-0')));
      await tester.enterText(
        find.byKey(const ValueKey('import-weight-0')),
        '35.5',
      );
      await enterEffort(tester, 'import-minutes-0', minutes: '30');
      await tapVisible(tester, find.byKey(const ValueKey('import-date-0')));
      await tester.tap(find.text('21').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Review import'));
      await tapVisible(tester, find.text('Save reviewed import'));
      expect(dependencies.tasks.courses, isEmpty);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('import-minutes-0-minutes')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('import-minutes-0-minutes')),
            )
            .controller!
            .text,
        '30',
      );
      await tapVisible(tester, find.text('Review import'));
      await tapVisible(
        tester,
        find.text('I reviewed the course and selected assessments.'),
      );
      await tapVisible(tester, find.text('Save reviewed import'));
      expect(dependencies.tasks.courses.length, 1);
      expect(dependencies.tasks.tasks.length, 6);
      expect(
        dependencies.tasks.tasks.last.deadline,
        DateTime(2026, 10, 21, 23, 59),
      );
      expect(dependencies.tasks.tasks.last.estimatedMinutes, 30);
      expect(dependencies.tasks.tasks.last.assessmentWeightPercent, 35.5);
      expect(dependencies.tasks.tasks.last.source!.assessmentWeight, 15);
      expect(dependencies.tasks.tasks.last.source!.rowId, 'continuous-1');
      final ranked = await tester.runAsync(
        () => dependencies.ranking.rank(
          dependencies.tasks.tasks,
          dependencies.clock.now(),
        ),
      );
      expect(ranked!.ranked.single.task.id, dependencies.tasks.tasks.last.id);
      expect(ranked.ranked.single.task.assessmentWeightPercent, 35.5);
      // Let the previous route's success notification finish before reimporting.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Open importer'));
      await tapVisible(tester, find.text('Choose PDF'));
      await tapVisible(tester, find.text('Continue to assessments'));
      expect(
        find.text('Already imported · existing task kept'),
        findsOneWidget,
      );
      // Rows skipped last time start selected again; skip them again.
      await untick(tester, [1, 2, 3, 4]);
      await tapVisible(tester, find.text('Review import'));
      await tapVisible(
        tester,
        find.text('I reviewed the course and selected assessments.'),
      );
      await tapVisible(tester, find.text('Save reviewed import'));
      expect(dependencies.tasks.tasks.length, 6);
      expect(dependencies.tasks.tasks.last.assessmentWeightPercent, 35.5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancel and extraction failure preserve records, and retry opens review',
    (tester) async {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      var calls = 0;
      await mountImporter(tester, dependencies, () async {
        calls++;
        if (calls == 1) throw const FormatException('Unsupported PDF.');
        return draft();
      });
      await tapVisible(tester, find.text('Choose PDF'));
      expect(find.text('Unsupported PDF.'), findsOneWidget);
      await tapVisible(tester, find.text('Try another PDF'));
      expect(find.text('Review proforma'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(dependencies.tasks.courses, isEmpty);
      expect(dependencies.tasks.tasks.length, 5);
      expect(tester.takeException(), isNull);
    },
  );
}
