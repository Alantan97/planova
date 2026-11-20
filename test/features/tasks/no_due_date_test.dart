import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/app/app_dependencies.dart';
import 'package:planova/app/planova_app.dart';
import 'package:planova/data/local/local_task_repository.dart';
import 'package:planova/data/local/task_codec.dart';
import 'package:planova/models/academic_task.dart';
import 'package:sembast/sembast_io.dart';

import '../../support/widget_actions.dart';

const waiting = AcademicTask(
  id: 'no-date',
  title: 'Final exam revision',
  subject: 'DES3113',
  description: '',
  estimatedMinutes: 120,
);

void main() {
  test('A task without a due date survives storage and sorts last', () async {
    final decoded = TaskCodec.decode(TaskCodec.encode([waiting]));
    expect(decoded.single.deadline, isNull);
    expect(decoded.single.hasDeadline, isFalse);
    expect(decoded.single.isOverdueAt(DateTime(2030)), isFalse);

    final dated = AcademicTask(
      id: 'dated',
      title: 'Quiz',
      subject: 'DES3113',
      description: '',
      deadline: DateTime(2026, 11, 1),
      estimatedMinutes: 30,
    );
    final sorted = [waiting, dated]..sort(AcademicTask.byDeadline);
    expect(sorted.map((t) => t.id), ['dated', 'no-date']);
    expect(waiting.copyWith(deadline: DateTime(2026, 12)).deadline, isNotNull);
    expect(
      dated.copyWith(clearDeadline: true).deadline,
      isNull,
      reason: 'clearDeadline removes a date',
    );

    final directory = await Directory.systemTemp.createTemp('planova_nodate_');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}tasks.db';
    var repo = await LocalTaskRepository.open(
      await databaseFactoryIo.openDatabase(path),
    );
    await repo.add(waiting);
    await repo.close();
    repo = await LocalTaskRepository.open(
      await databaseFactoryIo.openDatabase(path),
    );
    expect(repo.taskById('no-date')!.deadline, isNull);
    await repo.close();
  });

  testWidgets('Tasks list, details and form keep "no due date" honest', (
    tester,
  ) async {
    final d = AppDependencies.demo();
    addTearDown(d.tasks.dispose);
    await d.tasks.add(waiting);
    await tester.pumpWidget(MyApp(dependencies: d));
    await tester.pumpAndSettle();

    // Today's "Next deadline" never picks a task without a date.
    expect(find.text('Final exam revision'), findsNothing);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Final exam revision'));
    expect(find.text('Not set yet'), findsOneWidget);

    await tapVisible(tester, find.text('Edit task'));
    expect(find.text('Add due date'), findsOneWidget);
    expect(find.textContaining('No due date yet.'), findsOneWidget);
    await tapVisible(tester, find.text('Save task'));
    expect(d.tasks.taskById('no-date')!.deadline, isNull);

    // Adding a date, then choosing "No due date yet" removes it again.
    await tapVisible(tester, find.text('Edit task'));
    await tapVisible(tester, find.byKey(const ValueKey('task-add-deadline')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-clear-deadline')), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('task-clear-deadline')));
    await tapVisible(tester, find.text('Save task'));
    expect(d.tasks.taskById('no-date')!.deadline, isNull);
    expect(tester.takeException(), isNull);
  });
}
