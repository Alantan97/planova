import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../models/academic_task.dart';
import '../repositories/task_repository.dart';
import 'academic_records_codec.dart';
import '../repositories/academic_records.dart';
import '../../models/academic_course.dart';
import '../../models/proforma.dart';

class LocalTaskRepository extends TaskRepository {
  LocalTaskRepository._(this._database, this._records);
  static final _record = StoreRef<String, Map<String, Object?>>('planova')
      .record('tasks');
  final Database _database;
  AcademicRecords _records;
  Future<void> _pending = Future.value();
  Future<void>? _closeFuture;
  bool _closing = false;

  /// Seeds only an absent record. An explicitly empty list stays empty.
  /// Failed/corrupt reads are surfaced, never replaced with demo data.
  static Future<LocalTaskRepository> open(
    Database database, {
    List<AcademicTask> seedTasks = const [],
  }) async {
    try {
      final tasks = await database.transaction((transaction) async {
        final saved = await _record.get(transaction);
        if (saved != null) {
          final restored = AcademicRecordsCodec.decode(saved);
          if (saved['schemaVersion'] != 4) {
            await _record.put(
              transaction,
              AcademicRecordsCodec.encode(restored),
            );
          }
          return restored;
        }
        final encoded = AcademicRecordsCodec.encode(
          AcademicRecords(tasks: seedTasks),
        );
        final seed = AcademicRecordsCodec.decode(encoded);
        await _record.put(transaction, encoded);
        return seed;
      });
      return LocalTaskRepository._(database, tasks);
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  @override
  List<AcademicTask> get tasks => List.unmodifiable(_records.tasks);

  @override
  List<AcademicSemester> get semesters => List.unmodifiable(_records.semesters);
  @override
  List<AcademicCourse> get courses => List.unmodifiable(_records.courses);
  @override
  Future<ProformaImportResult> importProforma(
    AcademicCourse course,
    List<AcademicTask> tasks,
  ) => _change((records) => records.importProforma(course, tasks));
  @override
  Future<void> saveSemester(AcademicSemester semester, {required bool isNew}) =>
      _change((records) => records.saveSemester(semester, isNew: isNew));
  @override
  Future<void> saveCourse(AcademicCourse course, {required bool isNew}) =>
      _change((records) => records.saveCourse(course, isNew: isNew));
  @override
  Future<void> saveWeeklyLearning(
    String courseId,
    List<ReviewedWeeklyLearning> rows,
  ) => _change((records) => records.saveWeeklyLearning(courseId, rows));
  @override
  Future<void> deleteSemester(String id) =>
      _change((records) => records.deleteSemester(id));
  @override
  Future<void> deleteCourse(String id) =>
      _change((records) => records.deleteCourse(id));

  Future<T> _change<T>(T Function(AcademicRecords) mutate) {
    if (_closing) return Future.error(StateError('Task storage is closed.'));
    final operation = _pending.then((_) async {
      final committed = await _database.transaction((transaction) async {
        final saved = await _record.get(transaction);
        if (saved == null) {
          throw const FormatException('Task storage record is missing.');
        }
        final next = AcademicRecordsCodec.decode(saved);
        final result = mutate(next);
        next.synchronizeCourseLabels();
        // Validate before committing; the cache changes only after success.
        final encoded = AcademicRecordsCodec.encode(next);
        AcademicRecordsCodec.decode(encoded);
        await _record.put(transaction, encoded);
        return (records: next, result: result);
      });
      _records = committed.records;
      if (!_closing) notifyListeners();
      return committed.result;
    });
    // A failed write must not poison later retries or queued operations.
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  @override
  Future<void> add(AcademicTask task) => _change((records) {
    final tasks = records.tasks;
    if (tasks.any((item) => item.id == task.id)) {
      throw StateError('This task already exists.');
    }
    tasks.add(task);
  });

  @override
  Future<void> update(AcademicTask task) => _change((records) {
    final tasks = records.tasks;
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) throw StateError('This task no longer exists.');
    tasks[index] = task;
  });

  @override
  Future<void> delete(String id) =>
      _change((records) => records.tasks.removeWhere((task) => task.id == id));

  @override
  Future<void> setCompleted(String id, bool completed) => _change((records) {
    final tasks = records.tasks;
    final index = tasks.indexWhere((task) => task.id == id);
    if (index < 0) throw StateError('This task no longer exists.');
    tasks[index] = tasks[index].copyWith(
      status: completed ? TaskStatus.completed : TaskStatus.active,
    );
  });

  @override
  void dispose() {
    if (_closing) return;
    _closing = true;
    _closeFuture = _pending.then((_) => _database.close());
    super.dispose();
  }

  @override
  Future<void> close() {
    dispose();
    return _closeFuture!;
  }
}
