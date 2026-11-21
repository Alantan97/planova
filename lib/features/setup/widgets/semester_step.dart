import 'package:flutter/material.dart';

import '../../../core/widgets/near_limit_counter.dart';
import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_course.dart';
import '../../courses/screens/academic_record_form.dart';

import 'step_intro.dart';

String _date(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';

/// Shows the saved semester, or a short form when there is none yet.
/// The host screen's Continue button calls [SemesterStepState.submit].
class SemesterStep extends StatefulWidget {
  const SemesterStep({super.key, required this.tasks, required this.clock});
  final TaskRepository tasks;
  final AppClock clock;

  @override
  State<SemesterStep> createState() => SemesterStepState();
}

class SemesterStepState extends State<SemesterStep> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late DateTime _start = DateUtils.dateOnly(widget.clock.now());
  late DateTime _end = _start.add(const Duration(days: 120));
  bool saving = false;
  String? _error;

  AcademicSemester? get semester =>
      widget.tasks.currentSemester(widget.clock.now());

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// True when a semester exists afterwards (already saved or saved now).
  Future<bool> submit() async {
    if (semester != null) return true;
    if (saving || !_form.currentState!.validate()) return false;
    if (_end.isBefore(_start)) {
      setState(
        () => _error = 'The end date must be on or after the start date.',
      );
      return false;
    }
    setState(() {
      saving = true;
      _error = null;
    });
    try {
      await widget.tasks.saveSemester(
        AcademicSemester(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          name: _name.text.trim(),
          startDate: _start,
          endDate: _end,
        ),
        isNew: true,
      );
      if (mounted) setState(() => saving = false);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          saving = false;
          _error = academicSaveError(error);
        });
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.tasks,
    builder: (context, _) {
      final saved = semester;
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          const StepIntro(
            'When is your semester?',
            'Planova uses these dates to organise your courses and weeks.',
          ),
          if (saved != null)
            Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          saved.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_date(saved.startDate)} – ${_date(saved.endDate)}',
                          style: const TextStyle(color: planovaMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AcademicRecordForm(
                          repository: widget.tasks,
                          clock: widget.clock,
                          semester: saved,
                        ),
                      ),
                    ),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            )
          else
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('setup-semester-name'),
                    controller: _name,
                    enabled: !saving,
                    decoration: const InputDecoration(
                      labelText: 'Semester name',
                      hintText: 'e.g. Semester 1 · 2026/2027',
                    ),
                    maxLength: 100,
                    buildCounter: nearLimitCounter,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter a semester name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _dateButton('Starts', _start, (date) => _start = date),
                  const SizedBox(height: 12),
                  _dateButton('Ends', _end, (date) => _end = date),
                  const SizedBox(height: 16),
                  const Text(
                    'Find both dates in the UPSI academic calendar.',
                    style: TextStyle(color: planovaMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      );
    },
  );

  Widget _dateButton(
    String label,
    DateTime value,
    void Function(DateTime) set,
  ) => OutlinedButton.icon(
    onPressed: saving
        ? null
        : () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100, 12, 31),
            );
            if (picked != null && mounted) {
              setState(() {
                set(picked);
                _error = null;
              });
            }
          },
    icon: const Icon(Icons.calendar_month_outlined),
    label: Text('$label: ${_date(value)}'),
  );
}
