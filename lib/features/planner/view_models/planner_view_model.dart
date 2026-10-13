import 'package:flutter/foundation.dart';

import '../../../core/time/demo_clock.dart';
import '../../../data/repositories/study_repository.dart';
import '../../../models/study_session.dart';

class PlannerViewModel extends ChangeNotifier {
  PlannerViewModel({required this.repository, required this.clock})
    : _selectedDay = clock.now().weekday - 1;
  final StudyRepository repository;
  final AppClock clock;
  int _selectedDay;
  int _weekOffset = 0;

  int get selectedDay => _selectedDay;
  DateTime get weekStart {
    final start = startOfWeek(clock.now());
    return DateTime(start.year, start.month, start.day + _weekOffset * 7);
  }

  DateTime _day(int index) =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + index);
  List<StudySession> get sessions => repository.sessionsOn(_day(_selectedDay));
  bool hasSessions(int index) => repository.sessionsOn(_day(index)).isNotEmpty;

  void selectDay(int index) {
    if (index < 0 || index > 6 || index == _selectedDay) return;
    _selectedDay = index;
    notifyListeners();
  }

  void previousWeek() {
    _weekOffset--;
    notifyListeners();
  }

  void nextWeek() {
    _weekOffset++;
    notifyListeners();
  }

  void showToday() {
    _weekOffset = 0;
    _selectedDay = clock.now().weekday - 1;
    notifyListeners();
  }
}
