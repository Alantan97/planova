import 'package:flutter/foundation.dart';

import '../../models/weekly_availability.dart';

/// Storage contract for the student's normal week. Screens depend on this,
/// so the local implementation can later be replaced (e.g. by cloud sync).
abstract class AvailabilityRepository extends ChangeNotifier {
  WeeklyAvailability get availability;

  /// Adds the window, or replaces the one with the same ID.
  Future<void> saveWindow(StudyWindow window);
  Future<void> deleteWindow(String id);

  /// Adds the commitment, or replaces the one with the same ID.
  Future<void> saveCommitment(RecurringCommitment commitment);
  Future<void> deleteCommitment(String id);

  Future<void> close() async => dispose();
}

/// Shared change rules, so local and in-memory storage behave identically.
WeeklyAvailability upsertWindow(WeeklyAvailability current, StudyWindow item) =>
    WeeklyAvailability(
      windows: _upsert(current.windows, item, (w) => w.id == item.id),
      commitments: current.commitments,
    );

WeeklyAvailability removeWindow(WeeklyAvailability current, String id) =>
    WeeklyAvailability(
      windows: current.windows.where((w) => w.id != id),
      commitments: current.commitments,
    );

WeeklyAvailability upsertCommitment(
  WeeklyAvailability current,
  RecurringCommitment item,
) => WeeklyAvailability(
  windows: current.windows,
  commitments: _upsert(current.commitments, item, (c) => c.id == item.id),
);

WeeklyAvailability removeCommitment(WeeklyAvailability current, String id) =>
    WeeklyAvailability(
      windows: current.windows,
      commitments: current.commitments.where((c) => c.id != id),
    );

List<T> _upsert<T>(List<T> items, T item, bool Function(T) sameId) {
  final index = items.indexWhere(sameId);
  return index < 0 ? [...items, item] : ([...items]..[index] = item);
}

/// Non-persistent storage for the demo build and widget tests.
class MemoryAvailabilityRepository extends AvailabilityRepository {
  MemoryAvailabilityRepository([WeeklyAvailability? initial])
    : _availability = initial ?? WeeklyAvailability();
  WeeklyAvailability _availability;

  @override
  WeeklyAvailability get availability => _availability;

  void _set(WeeklyAvailability next) {
    _availability = next;
    notifyListeners();
  }

  @override
  Future<void> saveWindow(StudyWindow window) async =>
      _set(upsertWindow(_availability, window));
  @override
  Future<void> deleteWindow(String id) async =>
      _set(removeWindow(_availability, id));
  @override
  Future<void> saveCommitment(RecurringCommitment commitment) async =>
      _set(upsertCommitment(_availability, commitment));
  @override
  Future<void> deleteCommitment(String id) async =>
      _set(removeCommitment(_availability, id));
}
