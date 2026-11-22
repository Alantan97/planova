import 'package:flutter_test/flutter_test.dart';
import 'package:planova/data/local/local_profile_repository.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/models/onboarding_progress.dart';
import 'package:planova/models/study_preferences.dart';
import 'package:planova/models/weekly_availability.dart';
import 'package:planova/services/planning/rule_based_planner.dart';

/// Wednesday 14 October 2026, 13:00 (the app's preview clock).
final now = DateTime(2026, 10, 14, 13);

final weekdayEvenings = WeeklyAvailability(
  windows: [
    StudyWindow(
      id: 'w',
      range: WeeklyTimeRange(
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        startMinute: 18 * 60,
        endMinute: 22 * 60,
      ),
    ),
  ],
);

AcademicTask essay() => AcademicTask(
  id: 'essay',
  title: 'Essay',
  subject: 'DES3113',
  description: '',
  deadline: DateTime(2026, 10, 20, 23, 59),
  estimatedMinutes: 600,
);

void main() {
  test('Defaults equal the original baseline rules', () {
    const p = StudyPreferences();
    final s = PlannerSettings.fromPreferences(p);
    const baseline = PlannerSettings();
    expect(p.problem, isNull);
    expect(p.isDefault, isTrue);
    expect(s.minSessionMinutes, baseline.minSessionMinutes);
    expect(s.maxSessionMinutes, baseline.maxSessionMinutes);
    expect(s.breakMinutes, baseline.breakMinutes);
    expect(s.dailyLimitMinutes, baseline.dailyLimitMinutes);
    expect(s.perTaskDailyMinutes, baseline.perTaskDailyMinutes);
    expect(s.daysOff, isEmpty);
  });

  test('Clashing or unknown choices are rejected with a reason', () {
    const p = StudyPreferences();
    expect(
      p.copyWith(minSessionMinutes: 45, maxSessionMinutes: 30).problem,
      contains('shortest'),
    );
    expect(
      p.copyWith(perTaskDailyMinutes: 30, minSessionMinutes: 45).problem,
      contains('at least one session'),
    );
    expect(p.copyWith(dailyLimitMinutes: 60).problem, contains('daily limit'));
    expect(p.copyWith(breakMinutes: 7).problem, isNotNull);
    expect(
      p.copyWith(daysOff: {1, 2, 3, 4, 5, 6, 7}).problem,
      contains('one study day'),
    );
    expect(p.copyWith(daysOff: {6, 7}).problem, isNull);
  });

  test('The planner follows session length, breaks and the daily limit', () {
    final p = planWeek(
      tasks: [essay()],
      availability: weekdayEvenings,
      now: now,
      settings: PlannerSettings.fromPreferences(
        const StudyPreferences(
          minSessionMinutes: 15,
          maxSessionMinutes: 90,
          breakMinutes: 0,
          dailyLimitMinutes: 180,
          perTaskDailyMinutes: 180,
        ),
      ),
    );
    final wednesday = p.sessions
        .where((s) => s.startsAt.day == 14)
        .map((s) => '${s.time} ${s.minutes}')
        .toList();
    // 18:00–22:00 free: 90 + 90 back to back (no break), then the 3h limit.
    expect(wednesday, ['18:00 90', '19:30 90']);
    expect(p.sessions.every((s) => s.minutes <= 90), isTrue);
  });

  test('Nothing is planned on days off', () {
    final p = planWeek(
      tasks: [essay()],
      availability: weekdayEvenings,
      now: now,
      settings: PlannerSettings.fromPreferences(
        const StudyPreferences(daysOff: {3, 6, 7}),
      ),
    );
    expect(p.sessions, isNotEmpty);
    expect(
      p.sessions.map((s) => s.startsAt.weekday).toSet().intersection({3, 6, 7}),
      isEmpty,
    );
  });

  test('Preferences are saved with the profile; old records get defaults', () {
    const progress = OnboardingProgress(
      completed: true,
      accountType: AccountType.guest,
      preferences: StudyPreferences(
        maxSessionMinutes: 90,
        breakMinutes: 0,
        daysOff: {6, 7},
      ),
    );
    final map = ProfileCodec.encode(progress);
    expect(ProfileCodec.decode(map).preferences, progress.preferences);

    final old = Map<String, Object?>.of(map)..remove('preferences');
    expect(ProfileCodec.decode(old).preferences, const StudyPreferences());

    final broken = Map<String, Object?>.of(map)
      ..['preferences'] = {
        ...(map['preferences']! as Map),
        'daysOff': [1, 2, 3, 4, 5, 6, 7],
      };
    expect(() => ProfileCodec.decode(broken), throwsFormatException);
  });
}
