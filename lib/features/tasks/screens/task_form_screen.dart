import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/demo_clock.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_task.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.repository,
    required this.clock,
    this.task,
  });
  final TaskRepository repository;
  final AppClock clock;
  final AcademicTask? task;

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
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _description.dispose();
    _minutes.dispose();
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
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final task = AcademicTask(
      id: widget.task?.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: _title.text.trim(),
      subject: _subject.text.trim(),
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

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: true,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.task == null
                        ? 'Make room for your next goal.'
                        : 'A clearer plan starts here.',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start with the essentials. You can refine the details later.',
                    style: TextStyle(color: planovaMuted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('task-title'),
                    controller: _title,
                    decoration: _decoration(
                      'Task title',
                      hint: 'e.g. Complete database assignment',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a task title.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('task-subject'),
                    controller: _subject,
                    decoration: _decoration(
                      'Subject',
                      hint: 'e.g. Database Systems',
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a subject.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('task-duration'),
                    controller: _minutes,
                    decoration: _decoration(
                      'Estimated duration (minutes)',
                      hint: '60',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final duration = int.tryParse(value ?? '');
                      if (duration == null ||
                          duration < 1 ||
                          duration > 10080) {
                        return 'Enter 1–10080 minutes.';
                      }
                      if (duration < (widget.task?.completedMinutes ?? 0)) {
                        return 'Must cover the ${widget.task!.completedMinutes} minutes already recorded.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Deadline',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          '${_deadline.day} ${months[_deadline.month - 1]} ${_deadline.year}',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickTime,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(
                          TimeOfDay.fromDateTime(_deadline).format(context),
                        ),
                      ),
                    ],
                  ),
                  if (_deadline.isBefore(widget.clock.now()))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'This deadline has passed. The task will appear as overdue.',
                        style: TextStyle(color: planovaMuted),
                      ),
                    ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<TaskDifficulty>(
                    initialValue: _difficulty,
                    isExpanded: true,
                    decoration: _decoration('Difficulty'),
                    items: TaskDifficulty.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_label(value.name)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _difficulty = value!),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<TaskImportance>(
                    initialValue: _importance,
                    isExpanded: true,
                    decoration: _decoration('Importance'),
                    items: TaskImportance.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_label(value.name)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _importance = value!),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey('task-description'),
                    controller: _description,
                    decoration: _decoration(
                      'Description (optional)',
                      hint: 'What needs to be done?',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: planovaOrange,
                      foregroundColor: planovaOnOrange,
                    ),
                    child: Text(_saving ? 'Saving…' : 'Save task'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Prototype · Changes stay in this app session and reset when the app restarts.',
                    style: TextStyle(
                      color: planovaMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _label(String text) => '${text[0].toUpperCase()}${text.substring(1)}';
