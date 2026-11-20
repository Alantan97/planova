import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/effort_field.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_task.dart';

/// Small bottom sheet for the two things a task needs: a due date and a time
/// estimate. Used from Today's "Needs your input" list instead of the full
/// task form. "Decide later" closes it without changing anything.
Future<void> showDueDateSheet(
  BuildContext context, {
  required TaskRepository repository,
  required AppClock clock,
  required AcademicTask task,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _DueDateSheet(repository: repository, clock: clock, task: task),
);

class _DueDateSheet extends StatefulWidget {
  const _DueDateSheet({
    required this.repository,
    required this.clock,
    required this.task,
  });
  final TaskRepository repository;
  final AppClock clock;
  final AcademicTask task;

  @override
  State<_DueDateSheet> createState() => _DueDateSheetState();
}

class _DueDateSheetState extends State<_DueDateSheet> {
  final _form = GlobalKey<FormState>();
  late DateTime? _deadline = widget.task.deadline;
  late final _minutes = TextEditingController(
    text: '${widget.task.estimatedMinutes}',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = widget.clock.now();
    final initial = _deadline ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      currentDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (date != null && mounted) {
      setState(() {
        // Keep an existing time; otherwise due by the end of the day.
        _deadline = DateTime(
          date.year,
          date.month,
          date.day,
          _deadline?.hour ?? 23,
          _deadline?.minute ?? 59,
        );
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.update(
        widget.task.copyWith(
          deadline: _deadline,
          estimatedMinutes: int.parse(_minutes.text),
        ),
      );
      if (mounted) Navigator.pop(context);
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
    final task = widget.task;
    final weight = task.assessmentWeightPercent;
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
                Text(
                  [
                    task.subject,
                    if (weight != null) '${_number(weight)}% of grade',
                  ].join(' · '),
                  style: const TextStyle(color: planovaMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'When is it due?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('sheet-due-date'),
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _deadline == null
                        ? 'Choose a date'
                        : '${fullWeekdays[_deadline!.weekday - 1]}, ${_deadline!.day} ${months[_deadline!.month - 1]} ${_deadline!.year}',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Proformas do not list due dates. Check your course page or ask your lecturer.',
                  style: TextStyle(
                    color: planovaMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                EffortField(
                  fieldKey: 'sheet-effort',
                  controller: _minutes,
                  enabled: !_saving,
                  label: 'How long will it take?',
                  helper: task.source != null
                      ? 'Pre-filled from the proforma. Change it if your estimate differs.'
                      : null,
                  validate: (total) =>
                      validateEffort(total, recorded: task.completedMinutes),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('sheet-later'),
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Decide later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('sheet-save'),
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}
