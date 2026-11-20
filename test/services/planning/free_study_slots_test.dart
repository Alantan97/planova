import 'package:flutter_test/flutter_test.dart';
import 'package:planova/models/weekly_availability.dart';
import 'package:planova/services/planning/free_study_slots.dart';

int at(int hour, [int minute = 0]) => hour * 60 + minute;

StudyWindow window(String id, List<int> days, int start, int end) =>
    StudyWindow(
      id: id,
      range: WeeklyTimeRange(
        weekdays: days,
        startMinute: start,
        endMinute: end,
      ),
    );

RecurringCommitment commitment(List<int> days, int start, int end) =>
    RecurringCommitment(
      id: 'c$start',
      title: 'Lecture',
      category: CommitmentCategory.classes,
      range: WeeklyTimeRange(
        weekdays: days,
        startMinute: start,
        endMinute: end,
      ),
    );

FreeSlot slot(int day, int start, int end) =>
    FreeSlot(weekday: day, startMinute: start, endMinute: end);

void main() {
  test('Commitments cut study windows; untouched days keep full windows', () {
    final week = WeeklyAvailability(
      windows: [
        window('w', [1, 2], at(8), at(17)),
      ],
      commitments: [
        commitment([1], at(10), at(12)),
        commitment([1], at(14), at(15, 30)),
      ],
    );
    expect(freeStudySlots(week), [
      slot(1, at(8), at(10)),
      slot(1, at(12), at(14)),
      slot(1, at(15, 30), at(17)),
      slot(2, at(8), at(17)),
    ]);
    expect(freeMinutesPerWeek(week), 120 + 120 + 90 + 540);
  });

  test('Overlapping and touching windows merge before subtraction', () {
    final week = WeeklyAvailability(
      windows: [
        window('a', [3], at(18), at(20)),
        window('b', [3], at(19), at(21)),
        window('c', [3], at(21), at(22)),
      ],
      commitments: [
        commitment([3], at(19, 30), at(20, 30)),
      ],
    );
    expect(freeStudySlots(week), [
      slot(3, at(18), at(19, 30)),
      slot(3, at(20, 30), at(22)),
    ]);
  });

  test('A commitment covering a whole window leaves no free time', () {
    final week = WeeklyAvailability(
      windows: [
        window('w', [5], at(9), at(11)),
      ],
      commitments: [
        commitment([5], at(8), at(12)),
      ],
    );
    expect(freeStudySlots(week), isEmpty);
  });

  test('Commitments outside windows do not create or remove time', () {
    final week = WeeklyAvailability(
      windows: [
        window('w', [6], at(10), at(12)),
      ],
      commitments: [
        commitment([6], at(13), at(15)),
        commitment([7], at(10), at(12)),
      ],
    );
    expect(freeStudySlots(week), [slot(6, at(10), at(12))]);
  });

  test('Only commitments, or nothing at all, means no study time', () {
    expect(freeStudySlots(WeeklyAvailability()), isEmpty);
    expect(
      freeStudySlots(
        WeeklyAvailability(
          commitments: [
            commitment([1], at(8), at(10)),
          ],
        ),
      ),
      isEmpty,
    );
  });

  test('Time ranges reject impossible input', () {
    expect(
      () => WeeklyTimeRange(weekdays: [], startMinute: 0, endMinute: 60),
      throwsFormatException,
    );
    expect(
      () => WeeklyTimeRange(weekdays: [8], startMinute: 0, endMinute: 60),
      throwsFormatException,
    );
    expect(
      () =>
          WeeklyTimeRange(weekdays: [1], startMinute: at(22), endMinute: at(1)),
      throwsFormatException,
    );
    expect(
      () => WeeklyTimeRange(weekdays: [1], startMinute: 60, endMinute: 60),
      throwsFormatException,
    );
    final range = WeeklyTimeRange(
      weekdays: [3, 1, 3],
      startMinute: 0,
      endMinute: minutesPerDay,
    );
    expect(range.weekdays, [1, 3]);
    expect(range.minutesPerWeek, 2 * minutesPerDay);
  });
}
