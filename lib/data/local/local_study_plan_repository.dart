import 'package:sembast/sembast.dart';

import '../../models/study_session.dart';
import '../repositories/availability_repository.dart';
import '../repositories/study_plan_repository.dart';
import '../repositories/task_repository.dart';

/// Saves the accepted plan as one record next to tasks and availability.
/// Shares the task database but does not own it: [close] only waits for
/// queued writes; LocalTaskRepository closes the file.
class LocalStudyPlanRepository extends StudyPlanRepository {
  LocalStudyPlanRepository._(
    this._database,
    this._sessions, {
    required super.tasks,
    required super.availability,
  });
  static final _record = StoreRef<String, Map<String, Object?>>('planova')
      .record('study_plan');

  final Database _database;
  List<StudySession> _sessions;
  Future<void> _pending = Future.value();
  bool _closing = false;

  /// A missing record means no plan yet. A corrupt one is reported.
  static Future<LocalStudyPlanRepository> open(
    Database database, {
    required TaskRepository tasks,
    required AvailabilityRepository availability,
  }) async {
    final saved = await _record.get(database);
    return LocalStudyPlanRepository._(
      database,
      saved == null ? const [] : StudyPlanCodec.decode(saved),
      tasks: tasks,
      availability: availability,
    );
  }

  @override
  List<StudySession> get savedSessions => List.unmodifiable(_sessions);

  @override
  Future<void> acceptPlan(
    List<StudySession> sessions, {
    required DateTime from,
    required DateTime to,
  }) {
    if (_closing) return Future.error(StateError('Plan storage is closed.'));
    final operation = _pending.then((_) async {
      final next = StudyPlanRepository.replacing(_sessions, sessions, from, to);
      await _record.put(_database, StudyPlanCodec.encode(next));
      _sessions = next;
      if (!_closing) notifyListeners();
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  @override
  Future<void> close() async {
    if (_closing) return _pending;
    _closing = true;
    final pending = _pending;
    dispose();
    await pending;
  }
}

/// Versioned storage format for saved study sessions.
abstract final class StudyPlanCodec {
  static const schemaVersion = 1;

  static Map<String, Object?> encode(List<StudySession> sessions) => {
    'schemaVersion': schemaVersion,
    'sessions': [
      for (final s in sessions)
        {
          'id': s.id,
          'taskId': s.taskId,
          'title': s.title,
          'subject': s.subject,
          'startsAt': s.startsAt.toIso8601String(),
          'minutes': s.minutes,
          'status': s.status.name,
        },
    ],
  };

  static List<StudySession> decode(Map<String, Object?> map) {
    if (map['schemaVersion'] != schemaVersion || map['sessions'] is! List) {
      throw const FormatException('Unsupported study plan format.');
    }
    final ids = <String>{};
    return [
      for (final raw in map['sessions'] as List)
        () {
          if (raw is! Map) throw const FormatException('Invalid session.');
          final id = raw['id'];
          final startsAt = raw['startsAt'] is String
              ? DateTime.tryParse(raw['startsAt'] as String)
              : null;
          final minutes = raw['minutes'];
          final status = SessionStatus.values
              .where((s) => s.name == raw['status'])
              .firstOrNull;
          if (id is! String ||
              id.isEmpty ||
              !ids.add(id) ||
              raw['title'] is! String ||
              raw['subject'] is! String ||
              (raw['taskId'] != null && raw['taskId'] is! String) ||
              startsAt == null ||
              minutes is! int ||
              minutes <= 0 ||
              status == null) {
            throw const FormatException('Invalid saved study session.');
          }
          return StudySession(
            id: id,
            taskId: raw['taskId'] as String?,
            title: raw['title'] as String,
            subject: raw['subject'] as String,
            startsAt: startsAt,
            minutes: minutes,
            status: status,
          );
        }(),
    ];
  }
}
