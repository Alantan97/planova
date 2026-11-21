import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/study_plan_repository.dart';
import '../../../models/study_session.dart';
import '../../../services/planning/rule_based_planner.dart';

/// Review screen for a proposed plan. Nothing is saved until "Accept plan";
/// "Cancel" leaves any accepted plan exactly as it was.
class PlanProposalScreen extends StatefulWidget {
  const PlanProposalScreen({
    super.key,
    required this.proposal,
    required this.repository,
    this.settings = const PlannerSettings(),
    this.onSetAvailability,
  });
  final PlanProposal proposal;
  final StudyPlanRepository repository;
  final PlannerSettings settings;
  final VoidCallback? onSetAvailability;

  @override
  State<PlanProposalScreen> createState() => _PlanProposalScreenState();
}

class _PlanProposalScreenState extends State<PlanProposalScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final p = widget.proposal;
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
    final p = widget.proposal;
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
                      const Eyebrow('RULE-BASED PLAN · NOTHING SAVED YET'),
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
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
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
                          _UnplacedRow(
                            u,
                            'Needs a due date (add it from Today)',
                          ),
                        for (final u in overdue)
                          _UnplacedRow(u, 'Due date has passed · review it'),
                      ],
                      const SizedBox(height: 24),
                      _Rules(widget.settings),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const ValueKey('proposal-cancel'),
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const ValueKey('proposal-accept'),
                              onPressed: _saving || p.sessions.isEmpty
                                  ? null
                                  : _accept,
                              child: Text(_saving ? 'Saving…' : 'Accept plan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

/// The rules in plain words, so the plan is explainable to the student.
class _Rules extends StatelessWidget {
  const _Rules(this.settings);
  final PlannerSettings settings;
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
          'Planova uses fixed rules, not AI:\n'
          '• Earliest due date first, then higher grade weight.\n'
          '• Only inside your free study time, never over commitments.\n'
          '• Every session ends before its task is due.\n'
          '• Sessions up to ${formatDuration(settings.maxSessionMinutes)}, '
          'with ${settings.breakMinutes} min breaks.\n'
          '• At most ${formatDuration(settings.dailyLimitMinutes)} a day, and '
          '${formatDuration(settings.perTaskDailyMinutes)} a day per task.\n'
          '• Gaps shorter than ${settings.minSessionMinutes} min are left free.',
          style: const TextStyle(color: planovaMuted, height: 1.6),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
