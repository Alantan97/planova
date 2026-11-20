import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/core/time/demo_clock.dart';
import 'package:planova/data/mock/mock_task_repository.dart';
import 'package:planova/features/ranking/view_models/task_ranking_view_model.dart';
import 'package:planova/models/academic_task.dart';
import 'package:planova/services/ranking/task_ranking_service.dart';

class ControlledRanking extends TaskRankingService {
  final calls = <Completer<TaskRanking>>[];
  @override
  Future<TaskRanking> rank(List<AcademicTask> tasks, DateTime now) {
    final call = Completer<TaskRanking>();
    calls.add(call);
    return call.future;
  }
}

void main() {
  TaskRanking result(String id) => TaskRanking(
    modelId: id,
    asOf: const DemoClock().now(),
    ranked: [],
    unranked: [],
  );
  test(
    'Repository changes discard older responses; disposal ignores pending work',
    () async {
      final repo = MockTaskRepository();
      final service = ControlledRanking();
      final vm = TaskRankingViewModel(
        repository: repo,
        service: service,
        clock: const DemoClock(),
      );
      addTearDown(repo.dispose);
      expect(vm.loading, isTrue);
      await repo.update(repo.tasks.first.copyWith(title: 'Changed'));
      expect(service.calls.length, 2);
      service.calls[1].complete(result('new'));
      await Future<void>.delayed(Duration.zero);
      expect(vm.result!.modelId, 'new');
      service.calls[0].complete(result('stale'));
      await Future<void>.delayed(Duration.zero);
      expect(vm.result!.modelId, 'new');
      final pending = vm.refresh();
      expect(vm.result, isNull);
      vm.dispose();
      service.calls.last.complete(result('disposed'));
      await pending;
    },
  );

  test(
    'Failure is explicit and refresh can retry without changing records',
    () async {
      final repo = MockTaskRepository();
      final service = ControlledRanking();
      final vm = TaskRankingViewModel(
        repository: repo,
        service: service,
        clock: const DemoClock(),
      );
      addTearDown(vm.dispose);
      addTearDown(repo.dispose);
      service.calls.single.completeError(StateError('Bad asset'));
      await Future<void>.delayed(Duration.zero);
      expect(vm.error, isNotNull);
      expect(vm.result, isNull);
      expect(vm.loading, isFalse);
      final retry = vm.refresh();
      service.calls.last.complete(result('recovered'));
      await retry;
      expect(vm.error, isNull);
      expect(vm.result!.modelId, 'recovered');
      expect(repo.tasks.length, 5);
    },
  );
}
