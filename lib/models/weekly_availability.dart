/// A student's normal week: when they can study, and what is already fixed.
///
/// Times are minutes after midnight (09:30 = 570) so they are easy to compare
/// and store. Weekdays follow Dart's [DateTime.weekday]: Monday = 1 … Sunday = 7.
library;

const minutesPerDay = 24 * 60;

/// The same time on one or more days of a normal week, e.g. Mon + Wed 08:00–10:00.
///
/// Version 1 keeps each range inside a single day; overnight ranges are not
/// supported yet.
class WeeklyTimeRange {
  WeeklyTimeRange({
    required Iterable<int> weekdays,
    required this.startMinute,
    required this.endMinute,
  }) : weekdays = List.unmodifiable(weekdays.toSet().toList()..sort()) {
    final problem = validate(
      weekdays: this.weekdays,
      startMinute: startMinute,
      endMinute: endMinute,
    );
    if (problem != null) throw FormatException(problem);
  }

  /// Sorted, unique weekdays (1–7).
  final List<int> weekdays;
  final int startMinute;
  final int endMinute;

  int get minutesPerOccurrence => endMinute - startMinute;
  int get minutesPerWeek => minutesPerOccurrence * weekdays.length;

  /// Shared by the form and the constructor, so saved data obeys the same rules.
  static String? validate({
    required Iterable<int> weekdays,
    required int startMinute,
    required int endMinute,
  }) {
    if (weekdays.isEmpty) return 'Choose at least one day.';
    if (weekdays.any((day) => day < 1 || day > 7)) {
      return 'Days must be Monday to Sunday.';
    }
    if (startMinute < 0 || endMinute > minutesPerDay) {
      return 'Times must be within one day.';
    }
    if (endMinute <= startMinute) {
      return 'The end time must be after the start time. '
          'Overnight times are not supported yet.';
    }
    return null;
  }
}

/// A recurring period when the student is normally willing to study.
class StudyWindow {
  const StudyWindow({required this.id, required this.range});
  final String id;
  final WeeklyTimeRange range;
}

enum CommitmentCategory {
  classes('Class'),
  club('Club / society'),
  work('Part-time work'),
  personal('Personal'),
  other('Other');

  const CommitmentCategory(this.label);
  final String label;
}

/// A recurring activity that is never replaced by study, such as a lecture.
class RecurringCommitment {
  RecurringCommitment({
    required this.id,
    required String title,
    required this.category,
    required this.range,
  }) : title = title.trim() {
    if (this.title.isEmpty) {
      throw const FormatException('Enter a name for this commitment.');
    }
  }
  final String id;
  final String title;
  final CommitmentCategory category;
  final WeeklyTimeRange range;
}

class WeeklyAvailability {
  WeeklyAvailability({
    Iterable<StudyWindow> windows = const [],
    Iterable<RecurringCommitment> commitments = const [],
  }) : windows = List.unmodifiable(windows),
       commitments = List.unmodifiable(commitments);

  final List<StudyWindow> windows;
  final List<RecurringCommitment> commitments;

  bool get isEmpty => windows.isEmpty && commitments.isEmpty;
}
