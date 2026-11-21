import 'package:flutter/foundation.dart';

import '../../models/onboarding_progress.dart';

/// Storage contract for the guided journey's progress and the small profile.
abstract class ProfileRepository extends ChangeNotifier {
  OnboardingProgress get progress;
  Future<void> save(OnboardingProgress progress);
  Future<void> close() async => dispose();
}

/// Non-persistent profile for the demo build and tests. Defaults to a
/// finished journey so existing screens open straight on Today.
class MemoryProfileRepository extends ProfileRepository {
  MemoryProfileRepository([OnboardingProgress? initial])
    : _progress =
          initial ??
          const OnboardingProgress(
            completed: true,
            accountType: AccountType.guest,
          );
  OnboardingProgress _progress;

  @override
  OnboardingProgress get progress => _progress;

  @override
  Future<void> save(OnboardingProgress progress) async {
    _progress = progress;
    notifyListeners();
  }
}
