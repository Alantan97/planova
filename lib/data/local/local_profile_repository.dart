import 'package:sembast/sembast.dart';

import '../../models/onboarding_progress.dart';
import '../../models/study_preferences.dart';
import '../repositories/profile_repository.dart';

/// Saves journey progress as one record next to the other Planova records.
/// Shares the task database but does not own it.
class LocalProfileRepository extends ProfileRepository {
  LocalProfileRepository._(this._database, this._progress);
  static final _record = StoreRef<String, Map<String, Object?>>('planova')
      .record('profile');

  final Database _database;
  OnboardingProgress _progress;
  Future<void> _pending = Future.value();
  bool _closing = false;

  /// With no saved record, a student who already has data (from before the
  /// journey existed) is treated as finished, so they are not sent back to
  /// the welcome screen. A new student starts the journey.
  static Future<LocalProfileRepository> open(
    Database database, {
    required bool hasExistingData,
  }) async {
    final saved = await _record.get(database);
    return LocalProfileRepository._(
      database,
      saved != null
          ? ProfileCodec.decode(saved)
          : OnboardingProgress(
              completed: hasExistingData,
              accountType: hasExistingData
                  ? AccountType.guest
                  : AccountType.none,
            ),
    );
  }

  @override
  OnboardingProgress get progress => _progress;

  @override
  Future<void> save(OnboardingProgress progress) {
    if (_closing) return Future.error(StateError('Profile storage is closed.'));
    final operation = _pending.then((_) async {
      await _record.put(_database, ProfileCodec.encode(progress));
      _progress = progress;
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

abstract final class ProfileCodec {
  static const schemaVersion = 1;

  static Map<String, Object?> encode(OnboardingProgress p) => {
    'schemaVersion': schemaVersion,
    'completed': p.completed,
    'step': p.step,
    if (p.displayName != null) 'displayName': p.displayName,
    'accountType': p.accountType.name,
    'showExperimental': p.showExperimental,
    'preferences': {
      'minSession': p.preferences.minSessionMinutes,
      'maxSession': p.preferences.maxSessionMinutes,
      'break': p.preferences.breakMinutes,
      'dailyLimit': p.preferences.dailyLimitMinutes,
      'perTaskDaily': p.preferences.perTaskDailyMinutes,
      'daysOff': (p.preferences.daysOff.toList()..sort()),
    },
  };

  static OnboardingProgress decode(Map<String, Object?> map) {
    final completed = map['completed'];
    final step = map['step'];
    final name = map['displayName'];
    // Missing in records saved before the switch existed: off.
    final experimental = map['showExperimental'] ?? false;
    final account = AccountType.values
        .where((a) => a.name == map['accountType'])
        .firstOrNull;
    if (map['schemaVersion'] != schemaVersion ||
        completed is! bool ||
        step is! int ||
        step < 0 ||
        (name != null && name is! String) ||
        experimental is! bool ||
        account == null) {
      throw const FormatException('Invalid saved profile.');
    }
    return OnboardingProgress(
      completed: completed,
      step: step,
      displayName: name as String?,
      accountType: account,
      preferences: _decodePreferences(map['preferences']),
      showExperimental: experimental,
    );
  }

  /// Records saved before preferences existed have none: use the defaults.
  static StudyPreferences _decodePreferences(Object? value) {
    if (value == null) return const StudyPreferences();
    if (value is! Map) throw const FormatException('Invalid saved profile.');
    int number(String key) {
      final n = value[key];
      if (n is! int) throw const FormatException('Invalid saved profile.');
      return n;
    }

    final days = value['daysOff'];
    if (days is! List || days.any((d) => d is! int)) {
      throw const FormatException('Invalid saved profile.');
    }
    final preferences = StudyPreferences(
      minSessionMinutes: number('minSession'),
      maxSessionMinutes: number('maxSession'),
      breakMinutes: number('break'),
      dailyLimitMinutes: number('dailyLimit'),
      perTaskDailyMinutes: number('perTaskDaily'),
      daysOff: days.cast<int>().toSet(),
    );
    if (preferences.problem != null) {
      throw const FormatException('Invalid saved profile.');
    }
    return preferences;
  }
}
