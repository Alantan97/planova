import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/effort_field.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/study_plan_repository.dart';
import '../../../models/study_session.dart';

/// Bottom sheet to record what happened in a planned study session: done,
/// partly done (with minutes) or missed. Can be reopened to correct it.
Future<void> showRecordSessionSheet(
  BuildContext context, {
  required StudyPlanRepository plans,
  required StudySession session,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RecordSessionSheet(
      plans: plans,
      session: session,
      messenger: messenger,
    ),
  );
}

class _RecordSessionSheet extends StatefulWidget {
  const _RecordSessionSheet({
    required this.plans,
    required this.session,
    required this.messenger,
  });
  final StudyPlanRepository plans;
  final StudySession session;
  final ScaffoldMessengerState messenger;

  @override
  State<_RecordSessionSheet> createState() => _RecordSessionSheetState();
}

class _RecordSessionSheetState extends State<_RecordSessionSheet> {
  final _form = GlobalKey<FormState>();
  late SessionStatus? _choice = widget.session.isRecorded
      ? widget.session.status
      : null;
  late final _minutes = TextEditingController(
    text: widget.session.status == SessionStatus.partial
        ? '${widget.session.recordedMinutes ?? ''}'
        : '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final choice = _choice;
    if (_saving || choice == null) return;
    if (choice == SessionStatus.partial && !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.session;
    try {
      await widget.plans.recordOutcome(
        session.id,
        choice,
        recordedMinutes: choice == SessionStatus.partial
            ? int.parse(_minutes.text)
            : null,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = academicSaveError(error);
        });
      }
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    final tasks = widget.plans.tasks;
    final task = tasks.taskById(session.taskId ?? '');
    final left = task == null
        ? null
        : task.estimatedMinutes - task.completedMinutes;
    widget.messenger.showSnackBar(
      SnackBar(
        content: Text(switch (choice) {
          SessionStatus.missed =>
            'Marked as missed. Re-plan from Today when you are ready.',
          _ when task != null && !task.isCompleted && left! <= 0 =>
            'Recorded. No work left on ${task.title}.',
          _ => 'Session recorded.',
        }),
        action: task != null && !task.isCompleted && left! <= 0
            ? SnackBarAction(
                label: 'Mark complete',
                onPressed: () => tasks.setCompleted(task.id, true),
              )
            : null,
      ),
    );
  }

  Widget _option(
    SessionStatus status,
    String label,
    String detail,
    IconData icon,
  ) {
    final selected = _choice == status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? const Color(0xFFFFF4EC) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? planovaActionOrange : planovaBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            key: ValueKey('record-${status.name}'),
            borderRadius: BorderRadius.circular(14),
            onTap: _saving
                ? null
                : () => setState(() {
                    _choice = status;
                    _error = null;
                  }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: selected ? planovaActionOrange : planovaMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          detail,
                          style: const TextStyle(
                            color: planovaMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Eyebrow(
                  s.isRecorded
                      ? 'RECORDED · CHANGE IF NEEDED'
                      : 'HOW DID IT GO?',
                ),
                const SizedBox(height: 8),
                Text(
                  s.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.subject} · ${fullWeekdays[s.startsAt.weekday - 1]} ${s.time} · ${formatDuration(s.minutes)} planned',
                  style: const TextStyle(color: planovaMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),
                _option(
                  SessionStatus.completed,
                  'Done',
                  'Studied the whole ${formatDuration(s.minutes)}',
                  Icons.check_circle_outline_rounded,
                ),
                _option(
                  SessionStatus.partial,
                  'Partly done',
                  'Studied some of it',
                  Icons.timelapse_rounded,
                ),
                _option(
                  SessionStatus.missed,
                  'Missed',
                  'Did not study in this session',
                  Icons.event_busy_outlined,
                ),
                if (_choice == SessionStatus.partial) ...[
                  const SizedBox(height: 8),
                  EffortField(
                    fieldKey: 'record-minutes',
                    controller: _minutes,
                    enabled: !_saving,
                    label: 'How long did you study?',
                    validate: (total) {
                      if (total == null || total < 1) {
                        return 'Enter the minutes you studied.';
                      }
                      if (total >= s.minutes) {
                        return 'That is the whole session. Choose Done instead.';
                      }
                      return null;
                    },
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  key: const ValueKey('record-save'),
                  onPressed: _saving || _choice == null ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
