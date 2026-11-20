import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/academic_task.dart';
import 'lambda_mart_model.dart';

class RankedTask {
  const RankedTask({
    required this.task,
    required this.rank,
    required this.score,
    required this.daysUntilDue,
    required this.remainingMinutes,
    required this.outsideTrainingRange,
  });
  final AcademicTask task;
  final int rank;
  final double score;
  final int daysUntilDue;
  final int remainingMinutes;
  final bool outsideTrainingRange;
}

class UnrankedTask {
  const UnrankedTask(this.task, this.reason);
  final AcademicTask task;
  final String reason;
}

class TaskRanking {
  const TaskRanking({
    required this.modelId,
    required this.asOf,
    required this.ranked,
    required this.unranked,
  });
  final String modelId;
  final DateTime asOf;
  final List<RankedTask> ranked;
  final List<UnrankedTask> unranked;
}

abstract class TaskRankingService {
  Future<TaskRanking> rank(List<AcademicTask> tasks, DateTime now);
}

/// No network calls, training, storage writes, or fallback to a heuristic.
class LocalTaskRankingService implements TaskRankingService {
  LocalTaskRankingService({Future<String> Function()? loadModel})
    : _loadModel =
          loadModel ??
          (() => rootBundle.loadString('assets/ranking/provisional_v1.json'));
  final Future<String> Function() _loadModel;
  LambdaMartModel? _model;

  @override
  Future<TaskRanking> rank(List<AcademicTask> tasks, DateTime now) async {
    final model = _model ??= LambdaMartModel.fromJson(
      jsonDecode(await _loadModel()),
    );
    final scored =
        <
          ({
            AcademicTask task,
            double score,
            int days,
            int minutes,
            bool outside,
          })
        >[];
    final unranked = <UnrankedTask>[];
    final ids = <String>{};
    for (final task in tasks) {
      if (!ids.add(task.id)) throw ArgumentError('Duplicate task ID.');
      if (task.isCompleted) continue;
      final remaining = task.estimatedMinutes - task.completedMinutes;
      final weight = task.assessmentWeightPercent;
      final reason = !task.deadline.isAfter(now)
          ? 'Deadline reached. Review the deadline before ranking.'
          : remaining <= 0
          ? 'No work remaining. Mark complete or update your estimate.'
          : remaining > 10080
          ? 'Work remaining exceeds 10080 minutes. Review your estimate.'
          : weight == null
          ? 'Add a confirmed assessment weight in Edit task.'
          : !weight.isFinite || weight < 0 || weight > 100
          ? 'Enter an assessment weight from 0 to 100%.'
          : null;
      if (reason != null) {
        unranked.add(UnrankedTask(task, reason));
        continue;
      }
      // Calendar dates match the integer-day training schema. UTC construction
      // avoids DST-length days without converting the user's local date to UTC.
      final days = DateTime.utc(
        task.deadline.year,
        task.deadline.month,
        task.deadline.day,
      ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
      final values = [days.toDouble(), remaining.toDouble(), weight!];
      scored.add((
        task: task,
        score: model.predict(values),
        days: days,
        minutes: remaining,
        outside: model.outsideTrainingRange(values),
      ));
    }
    scored.sort((a, b) {
      final comparison = b.score.compareTo(a.score);
      return comparison == 0 ? a.task.id.compareTo(b.task.id) : comparison;
    });
    var rank = 0;
    double? previous;
    final ranked = <RankedTask>[];
    for (final row in scored) {
      if (previous == null || row.score != previous) rank++;
      ranked.add(
        RankedTask(
          task: row.task,
          rank: rank,
          score: row.score,
          daysUntilDue: row.days,
          remainingMinutes: row.minutes,
          outsideTrainingRange: row.outside,
        ),
      );
      previous = row.score;
    }
    unranked.sort((a, b) => a.task.deadline.compareTo(b.task.deadline));
    return TaskRanking(
      modelId: model.id,
      asOf: now,
      ranked: List.unmodifiable(ranked),
      unranked: List.unmodifiable(unranked),
    );
  }
}
