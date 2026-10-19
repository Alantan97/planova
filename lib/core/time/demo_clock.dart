import 'app_clock.dart';

/// A stable reference date keeps rehearsals and tests reproducible.
class DemoClock implements AppClock {
  const DemoClock();

  @override
  DateTime now() => DateTime(2026, 10, 14, 13);
}
