/// How the student likes to study. The rule-based planner reads these
/// instead of fixed limits. Defaults match the original baseline rules.
class StudyPreferences {
  const StudyPreferences({
    this.minSessionMinutes = 30,
    this.maxSessionMinutes = 60,
    this.breakMinutes = 15,
    this.dailyLimitMinutes = 240,
    this.perTaskDailyMinutes = 120,
    this.daysOff = const {},
  });

  /// Shortest session worth planning; smaller gaps stay free.
  final int minSessionMinutes;
  final int maxSessionMinutes;

  /// Break between two sessions in the same free slot.
  final int breakMinutes;
  final int dailyLimitMinutes;

  /// Most time on one task in a day, so long work spreads across days.
  final int perTaskDailyMinutes;

  /// Weekdays with no study (1 = Monday … 7 = Sunday).
  final Set<int> daysOff;

  // Choices offered in the app. Kept here so the screen and the checks agree.
  static const minSessionChoices = [15, 30, 45];
  static const maxSessionChoices = [30, 45, 60, 90, 120];
  static const breakChoices = [0, 5, 10, 15, 20, 30];
  static const dailyLimitChoices = [60, 120, 180, 240, 300, 360, 480];
  static const perTaskChoices = [30, 60, 90, 120, 180, 240];

  bool get isDefault => this == const StudyPreferences();

  /// Null when valid, otherwise a short reason.
  String? get problem {
    if (!minSessionChoices.contains(minSessionMinutes) ||
        !maxSessionChoices.contains(maxSessionMinutes) ||
        !breakChoices.contains(breakMinutes) ||
        !dailyLimitChoices.contains(dailyLimitMinutes) ||
        !perTaskChoices.contains(perTaskDailyMinutes)) {
      return 'Choose one of the listed options.';
    }
    if (minSessionMinutes > maxSessionMinutes) {
      return 'The shortest session cannot be longer than the longest.';
    }
    if (perTaskDailyMinutes < minSessionMinutes) {
      return 'Time per task must fit at least one session.';
    }
    if (perTaskDailyMinutes > dailyLimitMinutes) {
      return 'Time per task cannot be more than the daily limit.';
    }
    if (daysOff.any((d) => d < 1 || d > 7)) return 'Unknown weekday.';
    if (daysOff.length == 7) return 'Keep at least one study day.';
    return null;
  }

  StudyPreferences copyWith({
    int? minSessionMinutes,
    int? maxSessionMinutes,
    int? breakMinutes,
    int? dailyLimitMinutes,
    int? perTaskDailyMinutes,
    Set<int>? daysOff,
  }) => StudyPreferences(
    minSessionMinutes: minSessionMinutes ?? this.minSessionMinutes,
    maxSessionMinutes: maxSessionMinutes ?? this.maxSessionMinutes,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
    perTaskDailyMinutes: perTaskDailyMinutes ?? this.perTaskDailyMinutes,
    daysOff: daysOff ?? this.daysOff,
  );

  @override
  bool operator ==(Object other) =>
      other is StudyPreferences &&
      other.minSessionMinutes == minSessionMinutes &&
      other.maxSessionMinutes == maxSessionMinutes &&
      other.breakMinutes == breakMinutes &&
      other.dailyLimitMinutes == dailyLimitMinutes &&
      other.perTaskDailyMinutes == perTaskDailyMinutes &&
      other.daysOff.length == daysOff.length &&
      other.daysOff.containsAll(daysOff);

  @override
  String toString() =>
      'StudyPreferences($minSessionMinutes–$maxSessionMinutes min, '
      'break $breakMinutes, day $dailyLimitMinutes, task $perTaskDailyMinutes, '
      'off ${daysOff.toList()..sort()})';

  @override
  int get hashCode => Object.hash(
    minSessionMinutes,
    maxSessionMinutes,
    breakMinutes,
    dailyLimitMinutes,
    perTaskDailyMinutes,
    Object.hashAllUnordered(daysOff),
  );
}
