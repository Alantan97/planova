import 'study_preferences.dart';

/// How the student entered the app. Only [guest] works today; [google] is
/// reserved for real Google sign-in (Firebase Auth) later.
enum AccountType { none, guest, google }

/// Where the student is in the guided first-run journey, plus the small
/// profile it collects. Saved locally so "Finish later" resumes in place.
class OnboardingProgress {
  const OnboardingProgress({
    this.completed = false,
    this.step = 0,
    this.displayName,
    this.accountType = AccountType.none,
    this.preferences = const StudyPreferences(),
    this.showExperimental = false,
  });

  final bool completed;

  /// Index into the journey's screens (0 = welcome).
  final int step;
  final String? displayName;
  final AccountType accountType;

  /// Study preferences set on the Profile tab; the planner follows them.
  final StudyPreferences preferences;

  /// Experimental features (task ranking, weekly learning) are shown only
  /// when the student turns them on in Profile.
  final bool showExperimental;

  OnboardingProgress copyWith({
    bool? completed,
    int? step,
    String? displayName,
    bool clearName = false,
    AccountType? accountType,
    StudyPreferences? preferences,
    bool? showExperimental,
  }) => OnboardingProgress(
    completed: completed ?? this.completed,
    step: step ?? this.step,
    displayName: clearName ? null : displayName ?? this.displayName,
    accountType: accountType ?? this.accountType,
    preferences: preferences ?? this.preferences,
    showExperimental: showExperimental ?? this.showExperimental,
  );
}
