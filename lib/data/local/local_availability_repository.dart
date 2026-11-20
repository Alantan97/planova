import 'package:sembast/sembast.dart';

import '../../models/weekly_availability.dart';
import '../repositories/availability_repository.dart';
import 'availability_codec.dart';

/// Saves availability as one record next to the task records.
///
/// It shares the database opened for tasks but does not own it:
/// [close] only waits for queued writes; LocalTaskRepository closes the file.
class LocalAvailabilityRepository extends AvailabilityRepository {
  LocalAvailabilityRepository._(this._database, this._availability);
  static final _record = StoreRef<String, Map<String, Object?>>('planova')
      .record('availability');

  final Database _database;
  WeeklyAvailability _availability;
  Future<void> _pending = Future.value();
  bool _closing = false;

  /// A missing record means "nothing entered yet" and starts empty.
  /// A corrupt record is reported rather than replaced.
  static Future<LocalAvailabilityRepository> open(Database database) async {
    final saved = await _record.get(database);
    return LocalAvailabilityRepository._(
      database,
      saved == null ? WeeklyAvailability() : AvailabilityCodec.decode(saved),
    );
  }

  @override
  WeeklyAvailability get availability => _availability;

  @override
  Future<void> saveWindow(StudyWindow window) =>
      _change((current) => upsertWindow(current, window));
  @override
  Future<void> deleteWindow(String id) =>
      _change((current) => removeWindow(current, id));
  @override
  Future<void> saveCommitment(RecurringCommitment commitment) =>
      _change((current) => upsertCommitment(current, commitment));
  @override
  Future<void> deleteCommitment(String id) =>
      _change((current) => removeCommitment(current, id));

  /// Writes are queued one after another; the screen updates only after the
  /// database has accepted the change.
  Future<void> _change(WeeklyAvailability Function(WeeklyAvailability) mutate) {
    if (_closing) {
      return Future.error(StateError('Availability storage is closed.'));
    }
    final operation = _pending.then((_) async {
      final next = mutate(_availability);
      await _record.put(_database, AvailabilityCodec.encode(next));
      _availability = next;
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
