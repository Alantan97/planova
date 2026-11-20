import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/time/app_clock.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../services/ranking/task_ranking_service.dart';

class TaskRankingViewModel extends ChangeNotifier {
  TaskRankingViewModel({
    required this.repository,
    required this.service,
    required this.clock,
  }) {
    repository.addListener(_tasksChanged);
    unawaited(refresh());
  }
  final TaskRepository repository;
  final TaskRankingService service;
  final AppClock clock;
  TaskRanking? result;
  bool loading = false;
  String? error;
  bool _disposed = false;
  int _version = 0;

  void _tasksChanged() => unawaited(refresh());

  Future<void> refresh() async {
    if (_disposed) return;
    final version = ++_version;
    loading = true;
    error = null;
    result = null; // Never show an old ranking after a task edit or completion.
    notifyListeners();
    try {
      final latest = await service.rank(List.of(repository.tasks), clock.now());
      if (_disposed || version != _version) return;
      result = latest;
    } catch (_) {
      if (_disposed || version != _version) return;
      error = 'Could not load the experimental ranking. Your tasks are safe. Please try again.';
    }
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    repository.removeListener(_tasksChanged);
    super.dispose();
  }
}
