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
  });

  final bool completed;

  /// Index into the journey's screens (0 = welcome).
  final int step;
  final String? displayName;
  final AccountType accountType;

  OnboardingProgress copyWith({
    bool? completed,
    int? step,
    String? displayName,
    bool clearName = false,
    AccountType? accountType,
  }) => OnboardingProgress(
    completed: completed ?? this.completed,
    step: step ?? this.step,
    displayName: clearName ? null : displayName ?? this.displayName,
    accountType: accountType ?? this.accountType,
  );
}
