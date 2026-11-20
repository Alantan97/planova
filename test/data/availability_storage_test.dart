import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/data/local/availability_codec.dart';
import 'package:planova/data/local/local_availability_repository.dart';
import 'package:planova/data/local/local_task_repository.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/weekly_availability.dart';
import 'package:sembast/sembast_io.dart';

final studyWindow = StudyWindow(
  id: 'w1',
  range: WeeklyTimeRange(
    weekdays: [1, 3, 5],
    startMinute: 20 * 60,
    endMinute: 22 * 60,
  ),
);
final lecture = RecurringCommitment(
  id: 'c1',
  title: '  DES3113 lecture ',
  category: CommitmentCategory.classes,
  range: WeeklyTimeRange(weekdays: [2], startMinute: 480, endMinute: 600),
);

void main() {
  late Directory directory;
  late String path;
  Database? database;
  Future<Database> open() async {
    await database?.close();
    return database = await databaseFactoryIo.openDatabase(path);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('planova_availability_');
    path = '${directory.path}/records.db';
    database = null;
  });
  tearDown(() async {
    await database?.close();
    await databaseFactoryIo.deleteDatabase(path);
    await directory.delete(recursive: true);
  });

  test('Codec round-trips windows and commitments', () {
    final decoded = AvailabilityCodec.decode(
      AvailabilityCodec.encode(
        WeeklyAvailability(windows: [studyWindow], commitments: [lecture]),
      ),
    );
    expect(decoded.windows.single.range.weekdays, [1, 3, 5]);
    expect(decoded.windows.single.range.endMinute, 22 * 60);
    expect(decoded.commitments.single.title, 'DES3113 lecture');
    expect(decoded.commitments.single.category, CommitmentCategory.classes);
  });

  test('Corrupt or unknown saved data is reported, not repaired', () {
    final valid = AvailabilityCodec.encode(
      WeeklyAvailability(commitments: [lecture]),
    );
    expect(
      () => AvailabilityCodec.decode({...valid, 'schemaVersion': 99}),
      throwsFormatException,
    );
    expect(
      () => AvailabilityCodec.decode({
        ...valid,
        'commitments': [
          {
            ...(valid['commitments'] as List).single as Map<String, Object?>,
            'endMinute': 100,
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('Availability survives restart, edits replace by ID, and tasks are untouched', () async {
    final tasks = await LocalTaskRepository.open(await open());
    await tasks.add(
      AcademicTask(
        id: 't1',
        title: 'Lab report',
        subject: 'DES3113',
        description: '',
        deadline: DateTime(2026, 11, 30),
        estimatedMinutes: 120,
      ),
    );
    var repo = await LocalAvailabilityRepository.open(database!);
    expect(repo.availability.isEmpty, isTrue);
    await repo.saveWindow(studyWindow);
    await repo.saveCommitment(lecture);
    await repo.saveCommitment(
      RecurringCommitment(
        id: 'c1',
        title: 'Moved lecture',
        category: CommitmentCategory.classes,
        range: WeeklyTimeRange(weekdays: [4], startMinute: 600, endMinute: 720),
      ),
    );
    await repo.close();
    await tasks.close(); // Closes the shared database.
    database = null;

    final reopened = await open();
    repo = await LocalAvailabilityRepository.open(reopened);
    final restoredTasks = await LocalTaskRepository.open(reopened);
    expect(repo.availability.windows.single.id, 'w1');
    expect(repo.availability.commitments.single.title, 'Moved lecture');
    expect(repo.availability.commitments.single.range.weekdays, [4]);
    expect(restoredTasks.taskById('t1')?.title, 'Lab report');

    await repo.deleteWindow('w1');
    await repo.deleteCommitment('c1');
    await repo.close();
    await restoredTasks.close();
    database = null;

    final emptied = await LocalAvailabilityRepository.open(await open());
    expect(emptied.availability.isEmpty, isTrue);
    await emptied.close();
  });

  test('Writes after close are rejected', () async {
    final repo = await LocalAvailabilityRepository.open(await open());
    await repo.close();
    await expectLater(repo.saveWindow(studyWindow), throwsStateError);
  });
}
