import '../../models/weekly_availability.dart';

/// A free period on one weekday that a future planner may fill with study.
class FreeSlot {
  const FreeSlot({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });
  final int weekday;
  final int startMinute;
  final int endMinute;
  int get minutes => endMinute - startMinute;

  @override
  bool operator ==(Object other) =>
      other is FreeSlot &&
      other.weekday == weekday &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(weekday, startMinute, endMinute);

  @override
  String toString() => 'FreeSlot($weekday, $startMinute–$endMinute)';
}

/// Rule-based, explainable: free time = study windows minus commitments.
///
/// 1. Overlapping or touching study windows on the same day are merged.
/// 2. Every commitment is removed from those windows (commitments always win).
/// 3. What remains is returned in weekday and time order.
///
/// No preferences, breaks or task priorities are applied here; the future
/// study-session planner will place sessions inside these slots.
List<FreeSlot> freeStudySlots(WeeklyAvailability availability) => [
  for (var weekday = 1; weekday <= 7; weekday++)
    ..._subtract(
      _merge(_intervalsOn(weekday, availability.windows.map((w) => w.range))),
      _merge(
        _intervalsOn(weekday, availability.commitments.map((c) => c.range)),
      ),
    ).map(
      (interval) => FreeSlot(
        weekday: weekday,
        startMinute: interval.$1,
        endMinute: interval.$2,
      ),
    ),
];

int freeMinutesPerWeek(WeeklyAvailability availability) =>
    freeStudySlots(availability).fold(0, (total, slot) => total + slot.minutes);

typedef _Interval = (int, int);

List<_Interval> _intervalsOn(int weekday, Iterable<WeeklyTimeRange> ranges) => [
  for (final range in ranges)
    if (range.weekdays.contains(weekday)) (range.startMinute, range.endMinute),
];

List<_Interval> _merge(List<_Interval> intervals) {
  final sorted = [...intervals]..sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <_Interval>[];
  for (final interval in sorted) {
    if (merged.isNotEmpty && interval.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, interval.$2 > last.$2 ? interval.$2 : last.$2));
    } else {
      merged.add(interval);
    }
  }
  return merged;
}

/// Both lists must be merged and sorted.
List<_Interval> _subtract(List<_Interval> free, List<_Interval> busy) {
  final result = <_Interval>[];
  for (final window in free) {
    var start = window.$1;
    for (final block in busy) {
      if (block.$2 <= start || block.$1 >= window.$2) continue;
      if (block.$1 > start) result.add((start, block.$1));
      start = block.$2;
      if (start >= window.$2) break;
    }
    if (start < window.$2) result.add((start, window.$2));
  }
  return result;
}
