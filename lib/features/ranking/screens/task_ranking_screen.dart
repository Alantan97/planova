import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/demo_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_task.dart';
import '../../../services/ranking/task_ranking_service.dart';
import '../../tasks/screens/task_details_screen.dart';
import '../view_models/task_ranking_view_model.dart';

class TaskRankingScreen extends StatefulWidget {
  const TaskRankingScreen({
    super.key,
    required this.repository,
    required this.clock,
    required this.service,
  });
  final TaskRepository repository;
  final AppClock clock;
  final TaskRankingService service;

  @override
  State<TaskRankingScreen> createState() => _TaskRankingScreenState();
}

class _TaskRankingScreenState extends State<TaskRankingScreen> {
  late final _viewModel = TaskRankingViewModel(
    repository: widget.repository,
    service: widget.service,
    clock: widget.clock,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _about() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('About this ranking'),
      content: SingleChildScrollView(
        child: Text(
          'A saved LambdaMART model runs on this device. It uses days until due, work remaining, and the assessment percentage of the course grade.\n\n'
          'The experiment used machine-extracted proforma weights, simulated deadlines and effort, and provisional rule-generated priorities. It has not been independently validated for student decisions.\n\n'
          'Difficulty, importance, sleep and study preferences are not inputs to this model yet. Scores are relative values, not confidence percentages. Equal scores share a rank.\n\n'
          'This suggests an order for eligible tasks. It does not create a timetable, retrain itself, or change your tasks. No server or internet connection is needed.'
          '${_viewModel.result == null ? '' : '\n\nModel: ${_viewModel.result!.modelId}'}',
          style: const TextStyle(height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Prioritize tasks'),
      actions: [
        IconButton(
          onPressed: _about,
          tooltip: 'About this ranking',
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) {
              final result = _viewModel.result;
              return ListView(
                key: const PageStorageKey('task-ranking-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const FeaturedPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXPERIMENTAL RANKING',
                          style: TextStyle(
                            color: planovaOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'What to work on next',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Compare your tasks using their deadlines, remaining work and assessment weights.',
                          style: TextStyle(color: Colors.white70, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'An early model trained on provisional rules. Review the suggestions before deciding.',
                    style: TextStyle(color: planovaMuted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  if (_viewModel.loading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_viewModel.error != null)
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _viewModel.error!,
                            style: const TextStyle(height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _viewModel.refresh,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  else if (result != null) ...[
                    Text(
                      'Reference: ${result.asOf.day} ${months[result.asOf.month - 1]} ${result.asOf.year} · ${TimeOfDay.fromDateTime(result.asOf).format(context)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      widget.clock is DemoClock
                          ? 'Uses the app’s fixed preview clock, not today’s date. Refresh to recalculate.'
                          : 'Refresh to recalculate using the app clock.',
                      style: const TextStyle(
                        color: planovaMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _viewModel.refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh priorities'),
                    ),
                    const SizedBox(height: 24),
                    SectionTitle('Suggested order (${result.ranked.length})'),
                    const SizedBox(height: 6),
                    const Text(
                      'Tasks with the same rank are tied.',
                      style: TextStyle(
                        color: planovaMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (result.ranked.isEmpty)
                      const Panel(
                        child: Text(
                          'No tasks are ready to rank. Add active tasks with a future deadline, work remaining and a confirmed assessment weight.',
                          style: TextStyle(height: 1.5),
                        ),
                      )
                    else ...[
                      if (result.ranked.length == 1)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Only one task is eligible. Add another to compare priorities.',
                            style: TextStyle(color: planovaMuted, height: 1.5),
                          ),
                        ),
                      for (final item in result.ranked) _ranked(item),
                    ],
                    if (result.unranked.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SectionTitle(
                        'Needs attention (${result.unranked.length})',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'These active tasks are excluded from the model. Review them separately, especially overdue work.',
                        style: TextStyle(color: planovaMuted, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      for (final item in result.unranked) _unranked(item),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Runs on your device. Completed tasks are not ranked, and your tasks are not changed.',
                      style: const TextStyle(
                        color: planovaMuted,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _ranked(RankedTask item) => _taskPanel(
    item.task,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: ValueKey('rank-${item.task.id}'),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: planovaActionOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${item.rank}',
                textAlign: TextAlign.center,
                semanticsLabel: 'Priority rank ${item.rank}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _title(item.task)),
            const Icon(Icons.chevron_right_rounded, color: planovaMuted),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${item.daysUntilDue == 0 ? 'Due today' : '${item.daysUntilDue} days until due'} · ${formatDuration(item.remainingMinutes)} remaining · ${item.task.assessmentWeightPercent}% of course grade',
          style: const TextStyle(height: 1.6),
        ),
        if (item.outsideTrainingRange) ...[
          const SizedBox(height: 8),
          const Text(
            'Some inputs fall outside the model’s training range. Treat this suggestion with extra care.',
            style: TextStyle(color: planovaMuted, fontSize: 12, height: 1.5),
          ),
        ],
      ],
    ),
  );

  Widget _unranked(UnrankedTask item) => _taskPanel(
    item.task,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(item.task),
        const SizedBox(height: 8),
        Text(
          item.reason,
          style: const TextStyle(color: planovaMuted, height: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Open task',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: planovaActionOrange,
          ),
        ),
      ],
    ),
  );

  Widget _title(AcademicTask task) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        task.title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        task.subject,
        style: const TextStyle(color: planovaMuted, fontSize: 13, height: 1.4),
      ),
    ],
  );

  Widget _taskPanel(AcademicTask task, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: planovaBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            openTaskDetails(context, widget.repository, widget.clock, task.id),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}
