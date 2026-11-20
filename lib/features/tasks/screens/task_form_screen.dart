import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/effort_field.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_task.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.repository,
    required this.clock,
    this.task,
    this.initialCourseId,
  });
  final TaskRepository repository;
  final AppClock clock;
  final AcademicTask? task;
  final String? initialCourseId;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _subject = TextEditingController(text: widget.task?.subject);
  late final _description = TextEditingController(
    text: widget.task?.description,
  );
  late final _minutes = TextEditingController(
    text: '${widget.task?.estimatedMinutes ?? 60}',
  );
  late final _weight = TextEditingController(
    text: widget.task?.assessmentWeightPercent?.toString() ?? '',
  );
  late DateTime _deadline =
      widget.task?.deadline ??
      DateTime(
        widget.clock.now().year,
        widget.clock.now().month,
        widget.clock.now().day + 1,
        23,
        59,
      );
  late TaskDifficulty _difficulty =
      widget.task?.difficulty ?? TaskDifficulty.moderate;
  late TaskImportance _importance =
      widget.task?.importance ?? TaskImportance.medium;
  final _titleFocus = FocusNode();
  final _subjectFocus = FocusNode();
  final _minutesFocus = FocusNode();
  final _weightFocus = FocusNode();
  bool _saving = false;
  late String? _courseId = widget.task?.courseId ?? widget.initialCourseId;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _description.dispose();
    _minutes.dispose();
    _weight.dispose();
    _titleFocus.dispose();
    _subjectFocus.dispose();
    _minutesFocus.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = widget.clock.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 10, 12, 31);
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline.isBefore(first)
          ? first
          : _deadline.isAfter(last)
          ? last
          : _deadline,
      currentDate: now,
      firstDate: first,
      lastDate: last,
    );
    if (date != null && mounted) {
      setState(
        () => _deadline = DateTime(
          date.year,
          date.month,
          date.day,
          _deadline.hour,
          _deadline.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
    );
    if (time != null && mounted) {
      setState(
        () => _deadline = DateTime(
          _deadline.year,
          _deadline.month,
          _deadline.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) {
      final firstInvalid = _title.text.trim().isEmpty
          ? _titleFocus
          : _courseId == null && _subject.text.trim().isEmpty
          ? _subjectFocus
          : _validateMinutes(_minutes.text) != null
          ? _minutesFocus
          : _weightFocus;
      firstInvalid.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final task = AcademicTask(
      id: widget.task?.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: _title.text.trim(),
      subject:
          widget.repository.courseById(_courseId)?.label ??
          _subject.text.trim(),
      courseId: _courseId,
      source: widget.task?.source,
      assessmentWeightPercent: double.tryParse(_weight.text.trim()),
      description: _description.text.trim(),
      deadline: _deadline,
      estimatedMinutes: int.parse(_minutes.text),
      completedMinutes: widget.task?.completedMinutes ?? 0,
      difficulty: _difficulty,
      importance: _importance,
      status: widget.task?.status ?? TaskStatus.active,
    );
    try {
      if (widget.task == null) {
        await widget.repository.add(task);
      } else {
        await widget.repository.update(task);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this task. Please try again.'),
          ),
        );
      }
    }
  }

  InputDecoration _decoration(String label, {String? hint, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 4,
        errorMaxLines: 3,
        alignLabelWithHint: true,
      );

  Widget? _counter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    int? maxLength,
  }) => isFocused
      ? Text(
          '$currentLength/$maxLength',
          style: const TextStyle(color: planovaMuted, fontSize: 12),
        )
      : null;

  String? _validateMinutes(String? value) => validateEffort(
    int.tryParse(value ?? ''),
    recorded: widget.task?.completedMinutes ?? 0,
  );

  @override
  Widget build(BuildContext context) {
    final recorded = widget.task?.completedMinutes ?? 0;
    final total = int.tryParse(_minutes.text);
    final course = widget.repository.courseById(_courseId);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add task' : 'Edit task'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _form,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Add the essentials. Refine the details whenever you need.',
                            style: TextStyle(
                              color: planovaMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _TaskFormSection(
                            title: 'Task details',
                            icon: Icons.edit_note_rounded,
                            children: [
                              TextFormField(
                                key: const ValueKey('task-title'),
                                controller: _title,
                                focusNode: _titleFocus,
                                enabled: !_saving,
                                decoration: _decoration(
                                  'Task title',
                                  hint: 'e.g. Complete Exercise 3',
                                ),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction: TextInputAction.next,
                                maxLength: 100,
                                buildCounter: _counter,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter a task title.'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              DropdownButtonFormField<String>(
                                key: const ValueKey('task-course'),
                                initialValue: _courseId ?? '',
                                isExpanded: true,
                                decoration: _decoration('Course'),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('Enter subject manually'),
                                  ),
                                  ...widget.repository.courses.map(
                                    (course) => DropdownMenuItem(
                                      value: course.id,
                                      child: Text(
                                        '${course.label} · ${widget.repository.semesters.firstWhere((s) => s.id == course.semesterId).name}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (value) => setState(
                                        () => _courseId = value == ''
                                            ? null
                                            : value,
                                      ),
                              ),
                              if (_courseId == null) ...[
                                const SizedBox(height: 20),
                                TextFormField(
                                  key: const ValueKey('task-subject'),
                                  controller: _subject,
                                  focusNode: _subjectFocus,
                                  enabled: !_saving,
                                  decoration: _decoration(
                                    'Subject name',
                                    hint: 'e.g. Database Systems',
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  maxLength: 80,
                                  buildCounter: _counter,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Enter a subject.'
                                      : null,
                                ),
                              ],
                              if (course != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    course.label,
                                    style: const TextStyle(
                                      color: planovaMuted,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _TaskFormSection(
                            title: 'Deadline & effort',
                            icon: Icons.schedule_outlined,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _saving ? null : _pickDate,
                                    icon: const Icon(
                                      Icons.calendar_month_outlined,
                                      size: 20,
                                    ),
                                    label: Text(
                                      '${_deadline.day} ${months[_deadline.month - 1]} ${_deadline.year}',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _saving ? null : _pickTime,
                                    icon: const Icon(
                                      Icons.schedule_outlined,
                                      size: 20,
                                    ),
                                    label: Text(
                                      TimeOfDay.fromDateTime(_deadline)
                                          .format(context),
                                    ),
                                  ),
                                ],
                              ),
                              if (_deadline.isBefore(widget.clock.now()))
                                const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Text(
                                    'This deadline has passed. The task will appear as overdue.',
                                    style: TextStyle(
                                      color: planovaActionOrange,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              EffortField(
                                fieldKey: 'task-duration',
                                controller: _minutes,
                                focusNode: _minutesFocus,
                                enabled: !_saving,
                                label: 'Total estimated time',
                                helper: recorded > 0
                                    ? 'Include the ${formatDuration(recorded)} already recorded in this total.'
                                    : 'Your best guess for the whole task. You can change it later.',
                                validate: (_) =>
                                    _validateMinutes(_minutes.text),
                                onChanged: () => setState(() {}),
                              ),
                              if (recorded > 0 &&
                                  total != null &&
                                  total >= recorded)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    '${formatDuration(recorded)} recorded · ${formatDuration(total - recorded)} remaining',
                                    style: const TextStyle(
                                      color: planovaInk,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _TaskFormSection(
                            title: 'Task settings',
                            icon: Icons.tune_rounded,
                            children: [
                              TextFormField(
                                key: const ValueKey('task-weight'),
                                controller: _weight,
                                focusNode: _weightFocus,
                                enabled: !_saving,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _decoration(
                                  'Assessment weight (%) · optional',
                                  hint: 'e.g. 25',
                                  helper:
                                      widget.task?.source?.assessmentWeight ==
                                          null
                                      ? 'How much this counts towards your course grade. Leave blank if unknown.'
                                      : 'Your proforma says ${widget.task!.source!.assessmentWeight}%. Check it and correct it if needed.',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  final weight = double.tryParse(value.trim());
                                  return weight == null ||
                                          !weight.isFinite ||
                                          weight < 0 ||
                                          weight > 100
                                      ? 'Enter a percentage from 0 to 100, or leave blank.'
                                      : null;
                                },
                              ),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final difficulty =
                                      DropdownButtonFormField<TaskDifficulty>(
                                        initialValue: _difficulty,
                                        isExpanded: true,
                                        decoration: _decoration('Difficulty'),
                                        items: TaskDifficulty.values
                                            .map(
                                              (value) => DropdownMenuItem(
                                                value: value,
                                                child: Text(
                                                  _label(value.name),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _saving
                                            ? null
                                            : (value) => setState(
                                                () => _difficulty = value!,
                                              ),
                                      );
                                  final importance =
                                      DropdownButtonFormField<TaskImportance>(
                                        initialValue: _importance,
                                        isExpanded: true,
                                        decoration: _decoration('Importance'),
                                        items: TaskImportance.values
                                            .map(
                                              (value) => DropdownMenuItem(
                                                value: value,
                                                child: Text(
                                                  _label(value.name),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _saving
                                            ? null
                                            : (value) => setState(
                                                () => _importance = value!,
                                              ),
                                      );
                                  if (constraints.maxWidth >= 440 &&
                                      MediaQuery.textScalerOf(context)
                                              .scale(16) <=
                                          18) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: difficulty),
                                        const SizedBox(width: 16),
                                        Expanded(child: importance),
                                      ],
                                    );
                                  }
                                  return Column(
                                    children: [
                                      difficulty,
                                      const SizedBox(height: 20),
                                      importance,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: const ValueKey('task-notes'),
                              initiallyExpanded:
                                  widget.task?.description.isNotEmpty ?? false,
                              enabled: !_saving,
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              childrenPadding: const EdgeInsets.only(top: 8),
                              title: const Text(
                                'Notes (optional)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              leading: const Icon(
                                Icons.notes_rounded,
                                size: 20,
                                color: planovaInk,
                              ),
                              children: [
                                TextFormField(
                                  key: const ValueKey('task-description'),
                                  controller: _description,
                                  enabled: !_saving,
                                  decoration: _decoration(
                                    'Description',
                                    hint: 'Add instructions, links, or your next step.',
                                  ),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  minLines: 3,
                                  maxLines: 5,
                                  maxLength: 1000,
                                  buildCounter: _counter,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: planovaBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving…' : 'Save task'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tasks are saved on this device.',
                          textAlign: TextAlign.center,
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
  }
}

class _TaskFormSection extends StatelessWidget {
  const _TaskFormSection({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 20, color: planovaInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ...children,
    ],
  );
}

String _label(String text) => '${text[0].toUpperCase()}${text.substring(1)}';
