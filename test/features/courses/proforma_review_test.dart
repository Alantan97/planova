import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/core/theme/app_theme.dart';
import 'package:planova/features/courses/screens/proforma_import_screen.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/proforma.dart';
import 'package:planova/services/proforma/proforma_import_service.dart';

import '../../support/proforma_fixtures.dart';
import '../../support/widget_actions.dart';

Future<void> mountImporter(
  WidgetTester tester,
  AppDependencies dependencies,
  Future<ProformaDraft?> Function() loader,
) async {
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

void main() {
  Future<ProformaDraft> draft() =>
      ProformaImportService(
        reader: FakeTextReader([coursePage, assessmentPage]),
      ).extract(
        Uint8List.fromList(utf8.encode('%PDF-1.7 example')),
        fileName: 'example.pdf',
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
    await tapVisible(tester, find.byKey(const ValueKey('import-select-0')));
    await tapVisible(tester, find.byKey(const ValueKey('import-date-0')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Review requires deadline, effort and confirmation before saving; reimport keeps tasks',
    (tester) async {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      await mountImporter(tester, dependencies, draft);
      await tapVisible(tester, find.text('Choose PDF'));
      expect(dependencies.tasks.courses, isEmpty);
      await tapVisible(tester, find.text('Continue to assessments'));
      await tapVisible(tester, find.byKey(const ValueKey('import-select-0')));
      await tester.enterText(
        find.byKey(const ValueKey('import-minutes-0')),
        '30',
      );
      await tapVisible(tester, find.text('Review import'));
      expect(find.text('STEP 2 OF 3 · NOTHING SAVED YET'), findsOneWidget);
      expect(dependencies.tasks.tasks.length, 5);
      expect(dependencies.tasks.courses, isEmpty);
      await tapVisible(tester, find.byKey(const ValueKey('import-date-0')));
      await tester.tap(find.text('21').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Review import'));
      await tapVisible(tester, find.text('Save reviewed import'));
      expect(dependencies.tasks.courses, isEmpty);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('import-minutes-0')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('import-minutes-0')),
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
      expect(dependencies.tasks.tasks.last.source!.rowId, 'continuous-1');
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
      await tapVisible(tester, find.text('Review import'));
      await tapVisible(
        tester,
        find.text('I reviewed the course and selected assessments.'),
      );
      await tapVisible(tester, find.text('Save reviewed import'));
      expect(dependencies.tasks.tasks.length, 6);
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
