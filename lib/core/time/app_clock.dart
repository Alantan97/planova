abstract interface class AppClock {
  DateTime now();
}

/// The device's real date and time, used by the real app.
class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
