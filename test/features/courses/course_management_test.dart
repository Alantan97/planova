import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/models/academic_course.dart';

import '../../support/widget_actions.dart';

void main() {
  testWidgets('Existing manual task can select, change and unlink its course', (
    tester,
  ) async {
    final dependencies = AppDependencies.demo();
    addTearDown(dependencies.close);
    await dependencies.tasks.saveSemester(
      AcademicSemester(
        id: 's',
        name: 'Semester 1',
        startDate: DateTime(2026, 10),
        endDate: DateTime(2027, 2),
      ),
      isNew: true,
    );
    await dependencies.tasks.saveCourse(
      const AcademicCourse(
        id: 'c',
        semesterId: 's',
        code: 'DEQ3093',
        name: 'Example course',
      ),
      isNew: true,
    );
    await dependencies.tasks.saveCourse(
      const AcademicCourse(
        id: 'd',
        semesterId: 's',
        code: 'DXX1234',
        name: 'Another course',
      ),
      isNew: true,
    );
    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Database assignment'));
    await tapVisible(tester, find.text('Edit task'));
    await tapVisible(tester, find.byKey(const ValueKey('task-course')));
    await tester.tap(find.textContaining('DEQ3093').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save task'));
    expect(dependencies.tasks.taskById('database')!.courseId, 'c');
    await tapVisible(tester, find.text('Edit task'));
    await tapVisible(tester, find.byKey(const ValueKey('task-course')));
    await tester.tap(find.textContaining('DXX1234').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save task'));
    expect(dependencies.tasks.taskById('database')!.courseId, 'd');
    await tapVisible(tester, find.text('Edit task'));
    await tapVisible(tester, find.byKey(const ValueKey('task-course')));
    await tester.tap(find.text('Enter subject manually').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save task'));
    final task = dependencies.tasks.taskById('database')!;
    expect(task.courseId, isNull);
    expect(task.subject, 'DXX1234 · Another course');
    expect(task.completedMinutes, 60);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Create semester and course, add linked task, rename and protect records',
    (tester) async {
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Courses & semesters'));
      await tapVisible(tester, find.text('Add semester'));
      await tester.enterText(
        find.byKey(const ValueKey('academic-name')),
        'Semester 1 · 2026/2027',
      );
      await tapVisible(tester, find.text('Save semester'));
      expect(dependencies.tasks.semesters.length, 1);
      await tapVisible(tester, find.text('Add course'));
      await tester.enterText(
        find.byKey(const ValueKey('course-code')),
        'deq3093',
      );
      await tester.enterText(
        find.byKey(const ValueKey('academic-name')),
        'Example course',
      );
      await tapVisible(tester, find.text('Save course'));
      expect(dependencies.tasks.courses.single.code, 'DEQ3093');
      await tapVisible(tester, find.text('Add task'));
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Exercise 3',
      );
      await enterEffort(tester, 'task-duration', minutes: '30');
      await tapVisible(tester, find.text('Save task'));
      final task = dependencies.tasks.tasks.last;
      expect(task.courseId, dependencies.tasks.courses.single.id);
      expect(task.subject, 'DEQ3093 · Example course');
      expect(find.text('1 linked task'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Course options for DEQ3093'));
      await tapVisible(tester, find.text('Edit course'));
      await tester.enterText(
        find.byKey(const ValueKey('academic-name')),
        'Updated course',
      );
      await tapVisible(tester, find.text('Save course'));
      expect(dependencies.tasks.tasks.last.subject, 'DEQ3093 · Updated course');
      await tapVisible(tester, find.byTooltip('Course options for DEQ3093'));
      await tapVisible(tester, find.text('Delete course'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Move or unlink this course’s tasks before deleting it.'),
        findsOneWidget,
      );
      expect(dependencies.tasks.courses.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Course setup fits a small screen with larger text and validates required fields',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final dependencies = AppDependencies.demo();
      addTearDown(dependencies.close);
      await tester.pumpWidget(MyApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Courses & semesters'));
      await tapVisible(tester, find.text('Add semester'));
      await tapVisible(tester, find.text('Save semester'));
      expect(dependencies.tasks.semesters, isEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('academic-name')));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('academic-name')),
        'Semester 1 · 2026/2027',
      );
      await tapVisible(tester, find.text('Save semester'));
      await tapVisible(tester, find.text('Add course'));
      await tester.enterText(
        find.byKey(const ValueKey('course-code')),
        'DES3113',
      );
      await tester.enterText(
        find.byKey(const ValueKey('academic-name')),
        'Reka Bentuk dan Pembangunan Aplikasi Mobil / Mobile Application Design & Development',
      );
      await tapVisible(tester, find.text('Save course'));
      await tapVisible(tester, find.byTooltip('Course options for DES3113'));
      await tapVisible(tester, find.text('Edit course'));
      expect(find.text('Edit course'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
