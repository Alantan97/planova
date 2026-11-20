import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/data/local/task_codec.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/services/ranking/lambda_mart_model.dart';
import 'package:planova/services/ranking/task_ranking_service.dart';

void main() {
  final asset = File('assets/ranking/provisional_v1.json').readAsStringSync();
  final reference = jsonDecode(
    File('test/support/ranking_prediction_cases.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final model = LambdaMartModel.fromJson(jsonDecode(asset));
  final now = DateTime(2026, 10, 14, 13);
  AcademicTask task(
    String id, {
    double? weight = 25,
    DateTime? due,
    int estimated = 120,
    int recorded = 30,
    TaskStatus status = TaskStatus.active,
  }) => AcademicTask(
    id: id,
    title: id,
    subject: 'Test course',
    description: '',
    deadline: due ?? DateTime(2026, 10, 21, 23, 59),
    estimatedMinutes: estimated,
    completedMinutes: recorded,
    assessmentWeightPercent: weight,
    status: status,
  );

  test('Dart matches all Python LightGBM reference scores, including split boundaries', () {
    expect(model.sourceSha256, reference['sourceModelSha256']);
    for (final item in reference['cases'] as List) {
      final values = (item['values'] as List)
          .map((value) => (value as num).toDouble())
          .toList();
      expect(
        model.predict(values),
        closeTo((item['score'] as num).toDouble(), 1e-12),
        reason: 'Inputs: $values',
      );
    }
  });

  test(
    'Unsupported models and missing/nonfinite/out of range inputs are rejected',
    () {
      for (final changed in [
        {'formatVersion': 2},
        {
          'features': [
            'remaining_minutes',
            'days_until_due',
            'assessment_weight_percent',
          ],
        },
        {'trees': []},
        {
          'trees': [
            {
              'feature': 3,
              'threshold': 2,
              'left': {'value': 0},
              'right': {'value': 1},
            },
          ],
        },
        {
          'trees': [
            {'value': double.nan},
          ],
        },
      ]) {
        expect(
          () => LambdaMartModel.fromJson({
            ...jsonDecode(asset) as Map<String, dynamic>,
            ...changed,
          }),
          throwsFormatException,
        );
      }
      for (final values in <List<double>>[
        [1, 30],
        [double.nan, 30, 25],
        [-1, 30, 25],
        [0, 0, 25],
        [0, 10081, 25],
        [0, 30, 101],
      ]) {
        expect(() => model.predict(values), throwsArgumentError);
      }
    },
  );

  test('Ranking maps calendar days, subtracts recorded effort, preserves ties and records', () async {
    final service = LocalTaskRankingService(loadModel: () async => asset);
    final original = [
      task('b'),
      task('a'),
      task(
        'today',
        due: DateTime(2026, 10, 14, 23, 59),
        estimated: 60,
        recorded: 0,
      ),
    ];
    final before = jsonEncode(TaskCodec.encode(original));
    final result = await service.rank(original, now);
    expect(result.ranked.first.task.id, 'today');
    expect(result.ranked.first.daysUntilDue, 0);
    final a = result.ranked.firstWhere((row) => row.task.id == 'a');
    final b = result.ranked.firstWhere((row) => row.task.id == 'b');
    expect(a.daysUntilDue, 7);
    expect(a.remainingMinutes, 90);
    expect(a.score, model.predict([7, 90, 25]));
    expect(a.rank, b.rank);
    expect(result.ranked.indexOf(a), lessThan(result.ranked.indexOf(b)));
    expect(jsonEncode(TaskCodec.encode(original)), before);
    expect(result.asOf, now);
  });

  test('Completed, overdue, unknown weight and zero effort never receive invented scores', () async {
    final result = await LocalTaskRankingService(loadModel: () async => asset)
        .rank([
          task('completed', status: TaskStatus.completed),
          task('overdue', due: now),
          task('unknown', weight: null),
          task('no-work', estimated: 30, recorded: 30),
          task('zero-weight', weight: 0),
          task(
            'outside',
            estimated: 10080,
            recorded: 0,
            due: DateTime(2027, 1, 1),
          ),
        ], now);
    expect(result.unranked.map((row) => row.task.id).toSet(), {
      'overdue',
      'unknown',
      'no-work',
    });
    expect(result.ranked.map((row) => row.task.id).toSet(), {
      'zero-weight',
      'outside',
    });
    expect(result.ranked.every((row) => row.outsideTrainingRange), isTrue);
  });

  test('Assessment percentage round-trips; legacy values remain unknown and zero is preserved', () {
    final old = TaskCodec.encode([task('old', weight: null)]);
    expect(TaskCodec.decode(old).single.assessmentWeightPercent, isNull);
    for (final weight in [0.0, 25.5, 100.0]) {
      final stored = TaskCodec.decode(
        TaskCodec.encode([task('saved', weight: weight)]),
      ).single;
      expect(stored.assessmentWeightPercent, weight);
      expect(stored.copyWith(title: 'Renamed').assessmentWeightPercent, weight);
      expect(
        stored.copyWith(clearAssessmentWeight: true).assessmentWeightPercent,
        isNull,
      );
    }
    final bad = TaskCodec.encode([task('bad')]);
    (bad['tasks'] as List).single['assessmentWeightPercent'] = '25';
    expect(() => TaskCodec.decode(bad), throwsFormatException);
  });
}
