import 'package:flutter/material.dart';

import '../../../core/widgets/near_limit_counter.dart';
import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_course.dart';

class AcademicRecordForm extends StatefulWidget {
  const AcademicRecordForm({
    super.key,
    required this.repository,
    required this.clock,
    this.semester,
    this.course,
    this.semesterId,
  });
  final TaskRepository repository;
  final AppClock clock;
  final AcademicSemester? semester;
  final AcademicCourse? course;
  final String? semesterId;
  @override
  State<AcademicRecordForm> createState() => _AcademicRecordFormState();
}

class _AcademicRecordFormState extends State<AcademicRecordForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.course?.name ?? widget.semester?.name,
  );
  late final _code = TextEditingController(text: widget.course?.code);
  late String? _semesterId =
      widget.course?.semesterId ??
      widget.semesterId ??
      (widget.repository.semesters.length == 1
          ? widget.repository.semesters.single.id
          : null);
  late DateTime _start =
      widget.semester?.startDate ?? DateUtils.dateOnly(widget.clock.now());
  late DateTime _end =
      widget.semester?.endDate ?? _start.add(const Duration(days: 120));
  bool _saving = false;
  String? _error;
  bool get _isCourse => widget.course != null || widget.semesterId != null;
  bool get _isNew => widget.course == null && widget.semester == null;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? _start : _end;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() {
        if (start) {
          _start = selected;
        } else {
          _end = selected;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (!_isCourse && _end.isBefore(_start)) {
      setState(
        () => _error = 'The end date must be on or after the start date.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
      if (_isCourse) {
        await widget.repository.saveCourse(
          AcademicCourse(
            id: widget.course?.id ?? id,
            semesterId: _semesterId!,
            code: _code.text.trim().toUpperCase(),
            name: _name.text.trim(),
            source: widget.course?.source,
            weeklyLearning:
                widget.repository
                    .courseById(widget.course?.id)
                    ?.weeklyLearning ??
                const [],
          ),
          isNew: _isNew,
        );
      } else {
        await widget.repository.saveSemester(
          AcademicSemester(
            id: widget.semester?.id ?? id,
            name: _name.text.trim(),
            startDate: _start,
            endDate: _end,
          ),
          isNew: _isNew,
        );
      }
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${_isNew ? 'Add' : 'Edit'} ${_isCourse ? 'course' : 'semester'}',
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        _isCourse
                            ? 'A home for your coursework.'
                            : 'Set up your semester.',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isCourse
                            ? 'Use the code and name from your course proforma.'
                            : 'Use your academic calendar to confirm the dates.',
                        style: const TextStyle(
                          color: planovaMuted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // With one semester there is nothing to choose.
                      if (_isCourse &&
                          widget.repository.semesters.length > 1) ...[
                        DropdownButtonFormField<String>(
                          key: const ValueKey('course-semester'),
                          initialValue: _semesterId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Semester',
                          ),
                          items: widget.repository.semesters
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    s.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _semesterId = value),
                          validator: (value) =>
                              value == null ? 'Select a semester.' : null,
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_isCourse) ...[
                        TextFormField(
                          key: const ValueKey('course-code'),
                          controller: _code,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Course code',
                            hintText: 'e.g. DEQ3093',
                          ),
                          maxLength: 30,
                          buildCounter: nearLimitCounter,
                          textCapitalization: TextCapitalization.characters,
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        key: const ValueKey('academic-name'),
                        controller: _name,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: _isCourse
                              ? 'Course name'
                              : 'Semester name',
                          hintText: _isCourse
                              ? 'Full course name'
                              : 'e.g. Semester 1 · 2026/2027',
                        ),
                        maxLength: 100,
                        buildCounter: nearLimitCounter,
                        textCapitalization: TextCapitalization.words,
                        validator: _required,
                      ),
                      if (!_isCourse) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Semester dates',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Confirm both dates using your academic calendar.',
                          style: TextStyle(color: planovaMuted, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        _dateButton(
                          'Start date',
                          _start,
                          () => _pickDate(true),
                        ),
                        const SizedBox(height: 12),
                        _dateButton('End date', _end, () => _pickDate(false)),
                      ],
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
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: planovaActionOrange,
                          foregroundColor: planovaOnOrange,
                        ),
                        child: Text(
                          _saving
                              ? 'Saving…'
                              : _isCourse
                              ? 'Save course'
                              : 'Save semester',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Saved locally on this device.',
                        style: TextStyle(color: planovaMuted, fontSize: 12),
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

  Widget _dateButton(String label, DateTime date, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: _saving ? null : onTap,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(
          '$label: ${date.day} ${months[date.month - 1]} ${date.year}',
        ),
      );
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}
