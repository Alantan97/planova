import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:planova/data/local/local_task_repository.dart';
import 'package:planova/data/local/task_codec.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/proforma.dart';

AcademicTask exampleTask(String id) => AcademicTask(
  id: id,
  title: 'Exercise 3',
  subject: 'DEQ3093',
  description: 'Finish the remaining exercises.',
  deadline: DateTime(2026, 10, 21, 23, 59),
  estimatedMinutes: 30,
  difficulty: TaskDifficulty.easy,
  importance: TaskImportance.medium,
);

void main() {
  late Directory directory;
  late String path;
  LocalTaskRepository? repository;

  Future<LocalTaskRepository> reopen({
    List<AcademicTask> seed = const [],
  }) async {
    await repository?.close();
    repository = await LocalTaskRepository.open(
      await databaseFactoryIo.openDatabase(path),
      seedTasks: seed,
    );
    return repository!;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('planova_task_test_');
    path = '${directory.path}${Platform.pathSeparator}tasks.db';
    repository = null;
  });

  tearDown(() async {
    await repository?.close();
    await databaseFactoryIo.deleteDatabase(path);
    await directory.delete();
  });

  test('Schema 2 academic records upgrade without resetting course links or effort', () async {
    final database = await databaseFactoryIo.openDatabase(path);
    final record = StoreRef<String, Map<String, Object?>>('planova')
        .record('tasks');
    await record.put(database, {
      'schemaVersion': 2,
      'taskData': TaskCodec.encode([
        exampleTask('legacy-linked').copyWith(courseId: 'old-course'),
      ]),
      'semesters': [
        {
          'id': 'old-semester',
          'name': 'Previous semester',
          'startDate': DateTime(2026, 10).toIso8601String(),
          'endDate': DateTime(2027, 2).toIso8601String(),
        },
      ],
      'courses': [
        {
          'id': 'old-course',
          'semesterId': 'old-semester',
          'code': 'DEQ3093',
          'name': 'Previous course',
        },
      ],
    });
    await database.close();
    final repo = await reopen();
    expect(repo.tasks.single.courseId, 'old-course');
    expect(repo.tasks.single.estimatedMinutes, 30);
    expect(repo.courses.single.name, 'Previous course');
    expect(repo.semesters.single.id, 'old-semester');
    expect(repo.tasks.single.source, isNull);
    expect(repo.courses.single.source, isNull);
  });

  test('Reviewed import commits atomically and reimport preserves edited task progress', () async {
    var repo = await reopen();
    final semester = AcademicSemester(
      id: 's',
      name: 'Semester 1',
      startDate: DateTime(2026, 10),
      endDate: DateTime(2027, 2),
    );
    await repo.saveSemester(semester, isNew: true);
    final hash = List.filled(64, 'a').join();
    ProformaSource source(String row) => ProformaSource(
      fingerprint: hash,
      fileName: 'local.pdf',
      page: row == 'course' ? 1 : 9,
      rowId: row,
      excerpt: 'Verified example row',
      assessmentWeight: row == 'course' ? null : 25,
    );
    final course = AcademicCourse(
      id: 'c',
      semesterId: 's',
      code: 'DEQ3093',
      name: 'Example Course',
      source: source('course'),
    );
    AcademicTask task(
      String id,
      String row, {
      String title = 'Group assignment',
    }) => AcademicTask(
      id: id,
      title: title,
      subject: course.label,
      description: '',
      deadline: DateTime(2026, 10, 21, 23, 59),
      estimatedMinutes: 30,
      courseId: course.id,
      source: source(row),
    );
    await expectLater(
      repo.importProforma(course, [task('invalid', 'continuous-1', title: '')]),
      throwsFormatException,
    );
    expect(repo.courses, isEmpty);
    expect(repo.tasks, isEmpty);
    await repo.saveCourse(
      const AcademicCourse(
        id: 'manual-course',
        semesterId: 's',
        code: 'DEQ3093',
        name: 'Existing manual name',
      ),
      isNew: true,
    );
    final imported = await repo.importProforma(course, [
      task('a', 'continuous-1'),
      task('b', 'continuous-2'),
    ]);
    expect(imported.addedTasks, 2);
    expect(imported.courseId, 'manual-course');
    expect(repo.courses.single.name, 'Existing manual name');
    await repo.setCompleted('a', true);
    await repo.update(
      repo.taskById('a')!.copyWith(title: 'My edited assignment'),
    );
    repo = await reopen();
    final repeated = await repo.importProforma(course, [
      task('different-id', 'continuous-1'),
      task('another-id', 'continuous-2'),
    ]);
    expect(repeated.addedTasks, 0);
    expect(repeated.skippedTasks, 2);
    expect(repo.tasks.length, 2);
    expect(repo.taskById('a')!.title, 'My edited assignment');
    expect(repo.taskById('a')!.isCompleted, isTrue);
    expect(repo.taskById('a')!.source!.page, 9);
    expect(repo.taskById('a')!.source!.assessmentWeight, 25);
    expect(repo.courses.single.source!.fingerprint, hash);
    await repo.saveCourse(
      AcademicCourse(
        id: 'manual-course',
        semesterId: 's',
        code: 'DEQ3093',
        name: 'Manual rename',
        source: source('course'),
      ),
      isNew: false,
    );
    await repo.importProforma(course, []);
    repo = await reopen();
    expect(repo.courses.single.name, 'Manual rename');
    expect(repo.taskById('a')!.source!.fingerprint, hash);
  });

  test(
    'Task fields, edits, completion and reopening survive a disk reopen',
    () async {
      var repo = await reopen(seed: [exampleTask('seed')]);
      final task = exampleTask('new').copyWith(
        title: 'New work',
        subject: 'Another subject',
        description: 'Details',
        deadline: DateTime.utc(2027, 1, 2, 15, 59),
        estimatedMinutes: 90,
        difficulty: TaskDifficulty.challenging,
        importance: TaskImportance.high,
      );
      await repo.add(task);
      await repo.update(task.copyWith(title: 'Edited work'));
      await repo.setCompleted('new', true);
      repo = await reopen(seed: [exampleTask('unexpected-seed')]);
      final saved = repo.taskById('new')!;
      expect(saved.title, 'Edited work');
      expect(saved.subject, task.subject);
      expect(saved.description, task.description);
      expect(saved.deadline, task.deadline);
      expect(saved.deadline.isUtc, isTrue);
      expect(saved.estimatedMinutes, 90);
      expect(saved.completedMinutes, 0);
      expect(saved.difficulty, TaskDifficulty.challenging);
      expect(saved.importance, TaskImportance.high);
      expect(saved.isCompleted, isTrue);
      expect(repo.taskById('unexpected-seed'), isNull);
      await repo.setCompleted('new', false);
      repo = await reopen();
      expect(repo.taskById('new')!.isCompleted, isFalse);
      expect(repo.taskById('seed')!.deadline.hour, 23);
      expect(repo.taskById('seed')!.deadline.minute, 59);
    },
  );

  test(
    'Deleting every task stays empty and does not restore fixtures',
    () async {
      var repo = await reopen(seed: [exampleTask('seed')]);
      await repo.delete('seed');
      repo = await reopen(seed: [exampleTask('seed')]);
      expect(repo.tasks, isEmpty);
    },
  );

  test(
    'Queued changes preserve all updates and failed operations allow retry',
    () async {
      final repo = await reopen(seed: [exampleTask('seed')]);
      var notifications = 0;
      repo.addListener(() => notifications++);
      await Future.wait([
        repo.add(exampleTask('a')),
        repo.add(exampleTask('b')),
        repo.setCompleted('seed', true),
      ]);
      expect(repo.tasks.length, 3);
      expect(repo.taskById('seed')!.isCompleted, isTrue);
      expect(notifications, 3);
      await expectLater(
        repo.update(exampleTask('a').copyWith(title: ' ')),
        throwsFormatException,
      );
      expect(repo.taskById('a')!.title, 'Exercise 3');
      expect(notifications, 3);
      await repo.update(exampleTask('a').copyWith(title: 'Retry saved'));
      expect(notifications, 4);
      await expectLater(repo.add(exampleTask('a')), throwsStateError);
      await expectLater(repo.update(exampleTask('missing')), throwsStateError);
      final restored = await reopen();
      expect(restored.taskById('a')!.title, 'Retry saved');
      expect(restored.tasks.length, 3);
    },
  );

  test(
    'Unsupported data is reported and preserved without re-seeding',
    () async {
      final database = await databaseFactoryIo.openDatabase(path);
      final record = StoreRef<String, Map<String, Object?>>('planova')
          .record('tasks');
      final original = <String, Object?>{'schemaVersion': 99, 'tasks': []};
      await record.put(database, original);
      await expectLater(
        LocalTaskRepository.open(database, seedTasks: [exampleTask('seed')]),
        throwsFormatException,
      );
      final reopened = await databaseFactoryIo.openDatabase(path);
      expect(await record.get(reopened), original);
      await reopened.close();
    },
  );

  test('A database write failure leaves the visible task unchanged', () async {
    final database = await databaseFactoryIo.openDatabase(path);
    repository = await LocalTaskRepository.open(
      database,
      seedTasks: [exampleTask('seed')],
    );
    var notifications = 0;
    repository!.addListener(() => notifications++);
    await database.close();
    await expectLater(
      repository!.update(exampleTask('seed').copyWith(title: 'Unsaved')),
      throwsA(isA<Exception>()),
    );
    expect(repository!.taskById('seed')!.title, 'Exercise 3');
    expect(notifications, 0);
    final restored = await reopen();
    expect(restored.taskById('seed')!.title, 'Exercise 3');
  });

  test('Codec preserves recorded effort and rejects malformed records', () {
    final task = AcademicTask(
      id: 'partial',
      title: 'Partial work',
      subject: 'Course',
      description: '',
      deadline: DateTime(2026, 10, 21),
      estimatedMinutes: 60,
      completedMinutes: 15,
    );
    final encoded = TaskCodec.encode([task]);
    expect(TaskCodec.decode(encoded).single.completedMinutes, 15);
    final bad = TaskCodec.encode([task]);
    (bad['tasks'] as List).single['status'] = 'unknown';
    expect(() => TaskCodec.decode(bad), throwsFormatException);
    expect(
      () => TaskCodec.decode(TaskCodec.encode([task, task])),
      throwsFormatException,
    );
  });

  test(
    'Version 1 data migrates without inventing courses or changing work',
    () async {
      final database = await databaseFactoryIo.openDatabase(path);
      final original = exampleTask('legacy')
          .copyWith(status: TaskStatus.completed);
      final record = StoreRef<String, Map<String, Object?>>('planova')
          .record('tasks');
      await record.put(database, TaskCodec.encode([original]));
      await database.close();
      final repo = await reopen(seed: [exampleTask('not-restored')]);
      expect(repo.tasks.single.id, 'legacy');
      expect(repo.tasks.single.subject, 'DEQ3093');
      expect(repo.tasks.single.courseId, isNull);
      expect(repo.tasks.single.isCompleted, isTrue);
      expect(repo.tasks.single.estimatedMinutes, 30);
      expect(repo.tasks.single.deadline, original.deadline);
      expect(repo.semesters, isEmpty);
      expect(repo.courses, isEmpty);
      final reopened = await reopen();
      expect(reopened.tasks.single.id, 'legacy');
    },
  );

  test('Course links, renames and semesters persist; invalid references roll back', () async {
    var repo = await reopen();
    final semester = AcademicSemester(
      id: 's1',
      name: 'Semester 1 · 2026/2027',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2027, 2, 7),
    );
    const course = AcademicCourse(
      id: 'c1',
      semesterId: 's1',
      code: 'DEQ3093',
      name: 'Example course',
    );
    await repo.saveSemester(semester, isNew: true);
    await repo.saveCourse(course, isNew: true);
    await repo.add(exampleTask('linked').copyWith(courseId: 'c1'));
    await repo.setCompleted('linked', true);
    await expectLater(repo.deleteCourse('c1'), throwsStateError);
    await expectLater(repo.deleteSemester('s1'), throwsStateError);
    await expectLater(
      repo.add(exampleTask('bad-link').copyWith(courseId: 'missing')),
      throwsFormatException,
    );
    await expectLater(
      repo.saveCourse(
        const AcademicCourse(
          id: 'c2',
          semesterId: 's1',
          code: 'deq3093',
          name: 'Duplicate',
        ),
        isNew: true,
      ),
      throwsFormatException,
    );
    await expectLater(
      repo.saveSemester(
        AcademicSemester(
          id: 'bad',
          name: 'Invalid',
          startDate: DateTime(2027),
          endDate: DateTime(2026),
        ),
        isNew: true,
      ),
      throwsFormatException,
    );
    await repo.saveCourse(
      const AcademicCourse(
        id: 'c1',
        semesterId: 's1',
        code: 'DEQ3093',
        name: 'Renamed course',
      ),
      isNew: false,
    );
    repo = await reopen();
    expect(repo.semesters.single.startDate, semester.startDate);
    expect(repo.courses.single.name, 'Renamed course');
    expect(repo.tasks.single.courseId, 'c1');
    expect(repo.tasks.single.subject, 'DEQ3093 · Renamed course');
    expect(repo.tasks.single.isCompleted, isTrue);
    expect(repo.tasks.single.completedMinutes, 0);
    // Explicit unlink preserves the task and allows safe removal of its course.
    await repo.update(repo.tasks.single.copyWith(clearCourse: true));
    await repo.deleteCourse('c1');
    await repo.deleteSemester('s1');
    repo = await reopen();
    expect(repo.semesters, isEmpty);
    expect(repo.courses, isEmpty);
    expect(repo.tasks.single.courseId, isNull);
    expect(repo.tasks.single.subject, 'DEQ3093 · Renamed course');
  });
}
