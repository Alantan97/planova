import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/study_plan_repository.dart';
import '../../../models/study_session.dart';
import '../../../services/planning/balanced_plan_runner.dart';
import '../../../services/planning/ga_planner.dart';
import '../../../services/planning/rule_based_planner.dart';

/// How a proposed plan is made.
enum PlanMethod {
  /// The Genetic Algorithm: searches valid plans for the most even week that
  /// still meets deadlines (ga_planner.dart). The default.
  balanced,

  /// The fixed rules: earliest due date first (rule_based_planner.dart).
  earliestFirst,
}

/// Review screen for a proposed plan. Both methods plan from the same
/// inputs; the student switches between them and accepts one. Nothing is
/// saved until "Accept plan"; "Cancel" leaves any accepted plan as it was.
class PlanProposalScreen extends StatefulWidget {
  const PlanProposalScreen({
    super.key,
    required this.request,
    required this.repository,
    this.onSetAvailability,
  });
  final PlanRequest request;
  final StudyPlanRepository repository;
  final VoidCallback? onSetAvailability;

  @override
  State<PlanProposalScreen> createState() => _PlanProposalScreenState();
}

class _PlanProposalScreenState extends State<PlanProposalScreen> {
  bool _saving = false;
  String? _error;
  PlanMethod _method = PlanMethod.balanced;
  late final PlanProposal _rules;
  late final PlanGoalScore _rulesScore;
  BalancedPlanResult? _balanced;
  bool _balancedFailed = false;

  PlannerSettings get _settings => widget.request.settings;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _rules = planWeek(
      tasks: r.tasks,
      availability: r.availability,
      now: r.now,
      settings: r.settings,
    );
    _rulesScore = scorePlanGoal(
      proposal: _rules,
      tasks: r.tasks,
      availability: r.availability,
      now: r.now,
      settings: r.settings,
    );
    runBalancedPlan(r).then(
      (result) {
        if (mounted) setState(() => _balanced = result);
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('Balanced plan failed: $error');
        if (mounted) {
          setState(() {
            _balancedFailed = true;
            _method = PlanMethod.earliestFirst;
          });
        }
      },
    );
  }

  /// The plan on screen; null while the balanced plan is still being made.
  PlanProposal? get _shown =>
      _method == PlanMethod.balanced ? _balanced?.proposal : _rules;

  Future<void> _accept() async {
    final p = _shown;
    if (p == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.acceptPlan(p.sessions, from: p.from, to: p.to);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plan saved · ${p.sessions.length} study ${p.sessions.length == 1 ? 'session' : 'sessions'}.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = academicSaveError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _shown;
    return Scaffold(
      appBar: AppBar(title: const Text('Proposed plan')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      _MethodChoice(
                        method: _method,
                        balancedAvailable: !_balancedFailed,
                        onChanged: _saving
                            ? null
                            : (m) => setState(() => _method = m),
                      ),
                      if (_balancedFailed) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'The balanced plan could not be made, so the '
                          'earliest-first plan is shown.',
                          style: TextStyle(color: planovaMuted, height: 1.4),
                        ),
                      ],
                      if (_balanced != null && _rules.sessions.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _Comparison(
                          balanced: _balanced!,
                          rules: _rules,
                          rulesScore: _rulesScore,
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (p == null) const _Finding() else ..._planDetails(p),
                    ],
                  ),
                ),
                _actions(p),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _planDetails(PlanProposal p) {
    final byDay = <DateTime, List<StudySession>>{};
    for (final s in p.sessions) {
      final day = DateTime(s.startsAt.year, s.startsAt.month, s.startsAt.day);
      byDay.putIfAbsent(day, () => []).add(s);
    }
    List<UnplacedWork> of(UnplacedReason r) =>
        p.unplaced.where((u) => u.reason == r).toList();
    final short = of(UnplacedReason.notEnoughTimeBeforeDue);
    final later = of(UnplacedReason.continuesLater);
    final undated = of(UnplacedReason.needsDueDate);
    final overdue = of(UnplacedReason.overdue);
    final lastDay = p.to.subtract(const Duration(days: 1));

    return [
      Eyebrow(
        _method == PlanMethod.balanced
            ? 'BALANCED PLAN · NOTHING SAVED YET'
            : 'EARLIEST-FIRST PLAN · NOTHING SAVED YET',
      ),
      const SizedBox(height: 10),
      FeaturedPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.sessions.isEmpty
                  ? 'No sessions could be planned'
                  : '${p.sessions.length} ${p.sessions.length == 1 ? 'session' : 'sessions'} · ${formatDuration(p.scheduledMinutes)} · ${p.taskCount} ${p.taskCount == 1 ? 'task' : 'tasks'}',
              key: const ValueKey('proposal-summary'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${_day(p.from)} – ${_day(lastDay)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
      if (!p.hasAvailability) ...[
        const SizedBox(height: 20),
        _Notice(
          title: 'Set your weekly availability first',
          body: 'Planova only plans inside the times you say you can study.',
          action: widget.onSetAvailability == null
              ? null
              : TextButton(
                  onPressed: widget.onSetAvailability,
                  child: const Text('Set availability'),
                ),
        ),
      ],
      if (short.isNotEmpty) ...[
        const SizedBox(height: 24),
        const SectionTitle('Not enough time'),
        const SizedBox(height: 6),
        const Text(
          'This work could not fit before its due date. Add study time, or update the estimate.',
          style: TextStyle(color: planovaMuted, height: 1.4),
        ),
        const SizedBox(height: 10),
        for (final u in short)
          _UnplacedRow(
            u,
            '${formatDuration(u.minutes)} not placed · due ${_day(u.task.deadline!)}',
            warn: true,
          ),
      ],
      for (final entry in byDay.entries) ...[
        const SizedBox(height: 24),
        SectionTitle(_day(entry.key)),
        const SizedBox(height: 8),
        for (final s in entry.value) _SessionLine(s),
      ],
      if (later.isNotEmpty) ...[
        const SizedBox(height: 24),
        const SectionTitle('Continues after this week'),
        const SizedBox(height: 8),
        for (final u in later)
          _UnplacedRow(
            u,
            '${formatDuration(u.minutes)} left for later · due ${_day(u.task.deadline!)}',
          ),
      ],
      if (undated.isNotEmpty || overdue.isNotEmpty) ...[
        const SizedBox(height: 24),
        const SectionTitle('Not planned'),
        const SizedBox(height: 8),
        for (final u in undated)
          _UnplacedRow(u, 'Needs a due date (add it from Today)'),
        for (final u in overdue)
          _UnplacedRow(u, 'Due date has passed · review it'),
      ],
      const SizedBox(height: 24),
      _Rules(_settings, _method),
    ];
  }

  Widget _actions(PlanProposal? p) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('proposal-cancel'),
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const ValueKey('proposal-accept'),
                onPressed: _saving || p == null || p.sessions.isEmpty
                    ? null
                    : _accept,
                child: Text(_saving ? 'Saving…' : 'Accept plan'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  static String _day(DateTime d) =>
      '${fullWeekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}

class _SessionLine extends StatelessWidget {
  const _SessionLine(this.session);
  final StudySession session;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: planovaBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              session.time,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.subject} · ${formatDuration(session.minutes)}',
                  style: const TextStyle(color: planovaMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _UnplacedRow extends StatelessWidget {
  const _UnplacedRow(this.work, this.detail, {this.warn = false});
  final UnplacedWork work;
  final String detail;
  final bool warn;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn ? const Color(0xFFFFF4EC) : planovaSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            work.task.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${work.task.subject} · $detail',
            style: TextStyle(
              color: warn ? const Color(0xFF8F3300) : planovaMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body, this.action});
  final String title;
  final String body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(color: planovaMuted, height: 1.4)),
        ?action,
      ],
    ),
  );
}

String _daysOff(Set<int> days) {
  if (days.isEmpty) return '';
  final names = [
    for (var d = 1; d <= 7; d++)
      if (days.contains(d)) weekdays[d - 1],
  ];
  return '\n• Nothing on your days off (${names.join(', ')}).';
}

/// The rules in plain words, so the plan is explainable to the student.
class _Rules extends StatelessWidget {
  const _Rules(this.settings, this.method);
  final PlannerSettings settings;
  final PlanMethod method;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'How this plan was made',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Text(
          '${method == PlanMethod.balanced ? 'Balanced: Planova tried many valid plans with a search method (a genetic algorithm) and kept the one that best (1) places all work before it is due, (2) finishes each task a day early, (3) spreads study evenly across your days, and (4) uses fewer sessions. It is not trained AI, and the same inputs always give the same plan.' : 'Earliest first: Planova follows fixed rules, not AI. It fills your free time in order, giving each slot to the task due soonest, then the one worth more of your grade.'}\n\n'
          'Both methods keep the same limits:\n'
          '• Only inside your free study time, never over commitments.\n'
          '• Every session ends before its task is due.\n'
          '• Sessions up to ${formatDuration(settings.maxSessionMinutes)}, '
          'with ${settings.breakMinutes} min breaks.\n'
          '• At most ${formatDuration(settings.dailyLimitMinutes)} a day, and '
          '${formatDuration(settings.perTaskDailyMinutes)} a day per task.\n'
          '• Gaps shorter than ${settings.minSessionMinutes} min are left free.'
          '${_daysOff(settings.daysOff)}\n'
          'Change these in Profile → Study preferences.',
          style: const TextStyle(color: planovaMuted, height: 1.6),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

/// Balanced or earliest first. Chips wrap on narrow screens.
class _MethodChoice extends StatelessWidget {
  const _MethodChoice({
    required this.method,
    required this.balancedAvailable,
    required this.onChanged,
  });
  final PlanMethod method;
  final bool balancedAvailable;
  final ValueChanged<PlanMethod>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(
      PlanMethod m,
      String label,
      String key, {
      bool enabled = true,
    }) => ChoiceChip(
      key: ValueKey(key),
      label: Text(label),
      selected: method == m,
      showCheckmark: false,
      onSelected: enabled && onChanged != null ? (_) => onChanged!(m) : null,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          PlanMethod.balanced,
          'Balanced',
          'method-balanced',
          enabled: balancedAvailable,
        ),
        chip(PlanMethod.earliestFirst, 'Earliest first', 'method-earliest'),
      ],
    );
  }
}

/// Shown while the balanced plan is being made.
class _Finding extends StatelessWidget {
  const _Finding();
  @override
  Widget build(BuildContext context) => const Panel(
    key: ValueKey('balanced-loading'),
    child: Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        SizedBox(width: 14),
        Expanded(child: Text('Finding a balanced plan…')),
      ],
    ),
  );
}

/// The two plans side by side on what a student notices.
class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.balanced,
    required this.rules,
    required this.rulesScore,
  });
  final BalancedPlanResult balanced;
  final PlanProposal rules;
  final PlanGoalScore rulesScore;

  static bool _same(PlanProposal a, PlanProposal b) =>
      a.sessions.length == b.sessions.length &&
      [
        for (var i = 0; i < a.sessions.length; i++)
          a.sessions[i].taskId == b.sessions[i].taskId &&
              a.sessions[i].startsAt == b.sessions[i].startsAt &&
              a.sessions[i].minutes == b.sessions[i].minutes,
      ].every((same) => same);

  static int _busiest(PlanProposal p) =>
      p.minutesPerDay.values.fold(0, (a, b) => a > b ? a : b);

  static String _time(int minutes) =>
      minutes == 0 ? 'None' : formatDuration(minutes);

  @override
  Widget build(BuildContext context) {
    final b = balanced.proposal;
    if (_same(b, rules)) {
      return const Text(
        'Both methods give the same plan this week.',
        key: ValueKey('plan-comparison'),
        style: TextStyle(color: planovaMuted, height: 1.4),
      );
    }
    final missed =
        balanced.score.missedMinutes > 0 || rulesScore.missedMinutes > 0;
    TableRow row(String label, String left, String right, {bool head = false}) {
      final style = TextStyle(
        fontWeight: head ? FontWeight.w700 : FontWeight.w400,
        color: head ? null : planovaMuted,
        height: 1.35,
      );
      return TableRow(
        children: [
          for (final (i, text) in [label, left, right].indexed)
            Padding(
              // A gap after the label and middle columns, so a wrapped label
              // never runs into the value beside it.
              padding: EdgeInsets.fromLTRB(0, 4, i < 2 ? 12 : 0, 4),
              child: Text(text, style: style),
            ),
        ],
      );
    }

    return Panel(
      key: const ValueKey('plan-comparison'),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.6),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        children: [
          row('', 'Balanced', 'Earliest first', head: true),
          row(
            'Busiest day',
            formatDuration(_busiest(b)),
            formatDuration(_busiest(rules)),
          ),
          row(
            'Days with study',
            '${b.minutesPerDay.length}',
            '${rules.minutesPerDay.length}',
          ),
          row(
            'In the last day before due',
            _time(balanced.score.bufferMinutes),
            _time(rulesScore.bufferMinutes),
          ),
          if (missed)
            row(
              'Due work not placed',
              _time(balanced.score.missedMinutes),
              _time(rulesScore.missedMinutes),
            ),
        ],
      ),
    );
  }
}
