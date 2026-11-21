import 'package:sembast/sembast.dart';

import '../../models/study_session.dart';
import '../repositories/availability_repository.dart';
import '../repositories/study_plan_repository.dart';
import '../repositories/task_repository.dart';

/// Saves the plan and recorded outcomes as one record next to tasks and
/// availability. Shares the task database but does not own it: [close] only
/// waits for queued writes; LocalTaskRepository closes the file.
class LocalStudyPlanRepository extends StudyPlanRepository {
  LocalStudyPlanRepository._(
    this._database,
    StudyPlanState state, {
    required super.tasks,
    required super.availability,
  }) : _sessions = state.sessions,
       _needsReplan = state.needsReplan;
  static final _record = StoreRef<String, Map<String, Object?>>('planova')
      .record('study_plan');

  final Database _database;
  List<StudySession> _sessions;
  bool _needsReplan;
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
      saved == null
          ? const StudyPlanState([], needsReplan: false)
          : StudyPlanCodec.decode(saved),
      tasks: tasks,
      availability: availability,
    );
  }

  @override
  List<StudySession> get savedSessions => List.unmodifiable(_sessions);
  @override
  bool get needsReplan => _needsReplan;

  /// Writes are queued; the screen updates only after storage accepted them.
  @override
  Future<void> writeState(
    List<StudySession> sessions, {
    required bool needsReplan,
  }) {
    if (_closing) return Future.error(StateError('Plan storage is closed.'));
    final operation = _pending.then((_) async {
      final state = StudyPlanState(sessions, needsReplan: needsReplan);
      await _record.put(_database, StudyPlanCodec.encode(state));
      _sessions = List.of(sessions);
      _needsReplan = needsReplan;
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

class StudyPlanState {
  const StudyPlanState(this.sessions, {required this.needsReplan});
  final List<StudySession> sessions;
  final bool needsReplan;
}

/// Versioned storage format for saved study sessions.
///
/// Version 2 adds recorded minutes, the "partial" status and the re-plan
/// flag. Version 1 records (plans saved before outcomes existed) still load.
abstract final class StudyPlanCodec {
  static const schemaVersion = 2;

  static Map<String, Object?> encode(StudyPlanState state) => {
    'schemaVersion': schemaVersion,
    'needsReplan': state.needsReplan,
    'sessions': [
      for (final s in state.sessions)
        {
          'id': s.id,
          'taskId': s.taskId,
          'title': s.title,
          'subject': s.subject,
          'startsAt': s.startsAt.toIso8601String(),
          'minutes': s.minutes,
          'status': s.status.name,
          if (s.recordedMinutes != null) 'recordedMinutes': s.recordedMinutes,
        },
    ],
  };

  static StudyPlanState decode(Map<String, Object?> map) {
    final version = map['schemaVersion'];
    if ((version != 1 && version != 2) || map['sessions'] is! List) {
      throw const FormatException('Unsupported study plan format.');
    }
    final needsReplan = map['needsReplan'] ?? false;
    if (needsReplan is! bool) {
      throw const FormatException('Invalid study plan state.');
    }
    final ids = <String>{};
    return StudyPlanState(needsReplan: needsReplan, [
      for (final raw in map['sessions'] as List)
        () {
          if (raw is! Map) throw const FormatException('Invalid session.');
          final id = raw['id'];
          final startsAt = raw['startsAt'] is String
              ? DateTime.tryParse(raw['startsAt'] as String)
              : null;
          final minutes = raw['minutes'];
          final recorded = raw['recordedMinutes'];
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
              status == null ||
              (recorded != null && (recorded is! int || recorded < 0))) {
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
            recordedMinutes: recorded as int?,
          );
        }(),
    ]);
  }
}
