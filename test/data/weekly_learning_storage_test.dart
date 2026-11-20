import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:planova/data/local/local_task_repository.dart';
import 'package:planova/data/local/academic_records_codec.dart';
import 'package:planova/data/repositories/academic_records.dart';
import 'package:planova/models/academic_course.dart';
import 'package:planova/models/proforma.dart';

final hash = List.filled(64, 'a').join();
final otherHash = List.filled(64, 'b').join();
ProformaSource source(String id, {String? fingerprint}) => ProformaSource(
  fingerprint: fingerprint ?? hash,
  fileName: 'course.pdf',
  page: 4,
  rowId: id,
  excerpt: 'Original PDF evidence',
);
WeeklyLearningDraft row(
  String id, {
  String? fingerprint,
  String topic = 'Printed topic',
  int week = 6,
  double? hours,
}) => WeeklyLearningDraft(
  weekStart: week,
  weekEnd: week,
  topic: topic,
  guidedNf2fHours: hours,
  independentNf2fHours: 2,
  onlineHours: const [null, 1, 0, null],
  totalSltHours: 5,
  source: source(id, fingerprint: fingerprint),
);
AcademicCourse course({
  String? fingerprint,
  List<ReviewedWeeklyLearning> rows = const [],
}) => AcademicCourse(
  id: 'course',
  semesterId: 'semester',
  code: 'EXA1234',
  name: 'Example',
  source: source('course', fingerprint: fingerprint),
  weeklyLearning: rows,
);

void main() {
  late Directory directory;
  LocalTaskRepository? repo;
  Future<LocalTaskRepository> reopen() async {
    await repo?.close();
    return repo = await LocalTaskRepository.open(
      await databaseFactoryIo.openDatabase('${directory.path}/records.db'),
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('planova_weekly_');
    repo = null;
  });
  tearDown(() async {
    await repo?.close();
    await databaseFactoryIo.deleteDatabase('${directory.path}/records.db');
    await directory.delete();
  });
  Future<void> semester(LocalTaskRepository r) => r.saveSemester(
    AcademicSemester(
      id: 'semester',
      name: 'Semester 1',
      startDate: DateTime(2026, 10),
      endDate: DateTime(2027, 2),
    ),
    isNew: true,
  );

  test('Weekly edits, original blanks and repeated-week identities survive restart and reimport', () async {
    var r = await reopen();
    await semester(r);
    final printed = row('weekly-4-1');
    final second = row('weekly-4-2');
    final proposed = course(
      rows: [
        ReviewedWeeklyLearning(
          printed: printed,
          confirmed: printed.withOnlineZeros(),
        ),
        ReviewedWeeklyLearning(
          printed: second,
          confirmed: second.withOnlineZeros(),
        ),
      ],
    );
    final imported = await r.importProforma(proposed, []);
    expect(imported.addedWeeklyEntries, 2);
    expect(r.courses.single.weeklyLearning.length, 2);
    final saved = r.courses.single.weeklyLearning;
    await r.saveWeeklyLearning('course', [
      ReviewedWeeklyLearning(
        printed: printed,
        confirmed: row(
          'weekly-4-1',
          topic: 'Reviewed topic',
          week: 7,
          hours: 0.5,
        ).withOnlineZeros(),
      ),
      saved[1],
    ]);
    r = await reopen();
    final restored = r.courses.single.weeklyLearning.first;
    expect(restored.confirmed.weekStart, 7);
    expect(restored.confirmed.guidedNf2fHours, 0.5);
    expect(restored.printed.weekStart, 6);
    expect(restored.printed.guidedNf2fHours, isNull);
    expect(restored.printed.onlineHours, [null, 1, 0, null]);
    expect(restored.confirmed.onlineHours, [0, 1, 0, 0]);
    final repeated = await r.importProforma(proposed, []);
    expect(repeated.addedWeeklyEntries, 0);
    expect(repeated.skippedWeeklyEntries, 2);
    expect(
      r.courses.single.weeklyLearning.first.confirmed.topic,
      'Reviewed topic',
    );
    await r.saveCourse(
      AcademicCourse(
        id: 'course',
        semesterId: 'semester',
        code: 'EXA1234',
        name: 'Renamed',
        source: proposed.source,
      ),
      isNew: false,
    );
    expect(r.courses.single.weeklyLearning.length, 2);
    final newVersion = row('weekly-4-1', fingerprint: otherHash);
    final skipped = await r.importProforma(
      course(
        fingerprint: otherHash,
        rows: [
          ReviewedWeeklyLearning(
            printed: newVersion,
            confirmed: newVersion.withOnlineZeros(),
          ),
        ],
      ),
      [],
    );
    expect(skipped.addedWeeklyEntries, 0);
    expect(skipped.skippedWeeklyEntries, 1);
    r = await reopen();
    expect(r.courses.single.name, 'Renamed');
    expect(
      r.courses.single.weeklyLearning.first.confirmed.topic,
      'Reviewed topic',
    );
  });

  test(
    'Invalid weekly updates and imports roll back without replacing saved data',
    () async {
      var r = await reopen();
      await semester(r);
      final printed = row('weekly-4-1');
      final initial = ReviewedWeeklyLearning(
        printed: printed,
        confirmed: printed.withOnlineZeros(),
      );
      await r.importProforma(course(rows: [initial]), []);
      await expectLater(
        r.saveWeeklyLearning('course', [
          ReviewedWeeklyLearning(
            printed: printed,
            confirmed: row('weekly-4-1', hours: double.nan),
          ),
        ]),
        throwsFormatException,
      );
      await expectLater(r.saveWeeklyLearning('course', []), throwsStateError);
      await expectLater(
        r.saveWeeklyLearning('course', [
          ReviewedWeeklyLearning(
            printed: printed,
            confirmed: row('weekly-4-1', fingerprint: otherHash),
          ),
        ]),
        throwsFormatException,
      );
      final bad = row('weekly-4-2', hours: -1);
      await expectLater(
        r.importProforma(
          course(
            rows: [ReviewedWeeklyLearning(printed: bad, confirmed: bad)],
          ),
          [],
        ),
        throwsFormatException,
      );
      r = await reopen();
      expect(r.courses.single.weeklyLearning.length, 1);
      expect(
        r.courses.single.weeklyLearning.single.confirmed.guidedNf2fHours,
        isNull,
      );
    },
  );

  test('Schema 3 upgrades to 4 without guessed weekly records', () async {
    final database = await databaseFactoryIo.openDatabase(
      '${directory.path}/records.db',
    );
    final record = StoreRef<String, Map<String, Object?>>('planova')
        .record('tasks');
    final legacy = AcademicRecordsCodec.encode(
      AcademicRecords(
        semesters: [
          AcademicSemester(
            id: 'semester',
            name: 'Old semester',
            startDate: DateTime(2026, 10),
            endDate: DateTime(2027, 2),
          ),
        ],
        courses: [course()],
      ),
    );
    legacy['schemaVersion'] = 3;
    for (final c in legacy['courses'] as List) {
      (c as Map).remove('weeklyLearning');
    }
    await record.put(database, legacy);
    await database.close();
    var r = await reopen();
    expect(r.courses.single.code, 'EXA1234');
    expect(r.courses.single.weeklyLearning, isEmpty);
    await r.close();
    repo = null;
    final check = await databaseFactoryIo.openDatabase(
      '${directory.path}/records.db',
    );
    expect((await record.get(check))!['schemaVersion'], 4);
    await check.close();
    r = await reopen();
    expect(r.semesters.single.name, 'Old semester');
  });
}
