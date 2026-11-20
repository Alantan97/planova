import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/academic_task.dart';

import '../../support/widget_actions.dart';

Future<AppDependencies> withCourse() async {
  final d = AppDependencies.demo();
  await d.tasks.saveSemester(
    AcademicSemester(
      id: 's1',
      name: 'Semester 1',
      startDate: DateTime(2026, 10),
      endDate: DateTime(2027, 2),
    ),
    isNew: true,
  );
  await d.tasks.saveCourse(
    const AcademicCourse(
      id: 'c1',
      semesterId: 's1',
      code: 'DES3113',
      name: 'Mobile',
    ),
    isNew: true,
  );
  AcademicTask task(String id, String title, {DateTime? due}) => AcademicTask(
    id: id,
    title: title,
    subject: 'DES3113 · Mobile',
    description: '',
    deadline: due,
    estimatedMinutes: 120,
    courseId: 'c1',
  );
  await d.tasks.add(task('final', 'Final exam'));
  await d.tasks.add(
    task('quiz', 'Quiz 1', due: DateTime(2026, 10, 20, 23, 59)),
  );
  await d.tasks.add(task('lab', 'Lab 1', due: DateTime(2026, 10, 16, 23, 59)));
  await d.tasks.setCompleted('lab', true);
  return d;
}

void main() {
  testWidgets('Courses tab groups tasks by course with progress and order', (
    tester,
  ) async {
    final d = await withCourse();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courses'));
    await tester.pumpAndSettle();

    expect(find.text('Your courses'), findsOneWidget);
    expect(find.textContaining('Semester 1 · '), findsOneWidget);
    // The saved course comes first, then unlinked demo tasks by subject.
    expect(find.text('DES3113 · Mobile'), findsOneWidget);
    expect(find.text('1 of 3 done'), findsOneWidget);
    final quiz = tester.getTopLeft(find.text('Quiz 1')).dy;
    final exam = tester.getTopLeft(find.text('Final exam')).dy;
    final lab = tester.getTopLeft(find.text('Lab 1')).dy;
    expect(
      quiz < exam && exam < lab,
      isTrue,
      reason: 'dated first, undated next, completed last',
    );
    expect(find.text('Needs a due date · 2h of work'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);

    // Adding a task from the course preselects that course.
    await tapVisible(tester, find.text('Add task to this course'));
    expect(find.text('Add task'), findsWidgets);
    expect(find.text('DES3113 · Mobile'), findsWidgets);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // Rows open task details; course management stays one tap away.
    await tapVisible(tester, find.text('Final exam'));
    expect(find.text('Not set yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Courses & semesters'));
    expect(find.text('Your courses.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Courses tab fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final d = await withCourse();
    addTearDown(d.tasks.dispose);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courses'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
