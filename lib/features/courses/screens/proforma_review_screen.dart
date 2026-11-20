import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/effort_field.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_course.dart';
import '../../../models/academic_task.dart';
import '../../../models/proforma.dart';
import '../widgets/proforma_source_evidence.dart';
import 'weekly_learning_preview_screen.dart';

class ProformaReviewScreen extends StatefulWidget {
  const ProformaReviewScreen({
    super.key,
    required this.repository,
    required this.clock,
    required this.semesterId,
    required this.draft,
  });
  final TaskRepository repository;
  final AppClock clock;
  final String semesterId;
  final ProformaDraft draft;
  @override
  State<ProformaReviewScreen> createState() => _ProformaReviewScreenState();
}

class _AssessmentInput {
  _AssessmentInput(this.draft)
    : title = TextEditingController(text: draft.title),
      weight = TextEditingController(
        text: draft.source.assessmentWeight?.toString() ?? '',
      ),
      minutes = TextEditingController(
        text: suggestedMinutes(draft)?.toString() ?? '',
      );
  final AssessmentDraft draft;
  final TextEditingController title;
  final TextEditingController weight;
  final TextEditingController minutes;

  /// Every new assessment starts selected; students untick what they skip.
  bool selected = true;

  /// Optional: proformas do not print due dates, so this may stay empty.
  DateTime? deadline;

  /// Title and weight are prefilled; their editors stay hidden until asked.
  bool editDetails = false;

  /// Effort suggestion from the printed SLT hours, when they are usable.
  static int? suggestedMinutes(AssessmentDraft draft) {
    final hours = draft.sltHours;
    if (hours == null || !hours.isFinite || hours <= 0) return null;
    final minutes = (hours * 60).round();
    return minutes > maxEffortMinutes ? null : minutes;
  }

  void dispose() {
    title.dispose();
    weight.dispose();
    minutes.dispose();
  }
}

class _ProformaReviewScreenState extends State<ProformaReviewScreen> {
  final _courseForm = GlobalKey<FormState>();
  final _assessmentForm = GlobalKey<FormState>();
  int _step = 0;
  late final _code = TextEditingController(text: widget.draft.courseCode);
  late final _name = TextEditingController(text: widget.draft.courseName);
  late final _rows = widget.draft.assessments
      .map(_AssessmentInput.new)
      .toList();
  late String _semesterId = widget.semesterId;
  late List<WeeklyLearningDraft> _weeklyRows = widget.draft.weeklyLearning
      .map((row) => row.withOnlineZeros())
      .toList();
  bool get _otherWeeklyVersion =>
      _existing?.weeklyLearning.any(
        (row) =>
            row.printed.source.fingerprint !=
            widget.draft.courseSource.fingerprint,
      ) ??
      false;
  int get _newWeeklyCount {
    if (_otherWeeklyVersion) return 0;
    final saved =
        _existing?.weeklyLearning.map((row) => row.identity).toSet() ??
        <String>{};
    return _weeklyRows
        .where(
          (row) =>
              !saved.contains('${row.source.fingerprint}/${row.source.rowId}'),
        )
        .length;
  }

  Future<void> _reviewWeekly() async {
    final saved = {
      for (final row in _existing?.weeklyLearning ?? <ReviewedWeeklyLearning>[])
        row.identity: row,
    };
    final otherVersion = _otherWeeklyVersion;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WeeklyLearningPreviewScreen(
          rows: [
            for (final row in _weeklyRows)
              saved['${row.source.fingerprint}/${row.source.rowId}']
                      ?.confirmed ??
                  row,
          ],
          lockedIdentities: saved.keys.toSet(),
          description: otherVersion
              ? 'This course already has weekly learning from another PDF version. Those saved entries will be kept; weekly entries from this document will not be added.'
              : 'Review and correct the entries. New entries will be saved with the final import. Already saved entries are kept on reimport.',
          saveLabel: 'Use reviewed entries',
          onSave: otherVersion
              ? null
              : (rows) async {
                  if (mounted) setState(() => _weeklyRows = List.of(rows));
                },
        ),
      ),
    );
  }

  bool _confirmed = false;
  bool _saving = false;
  String? _error;
  AcademicCourse? get _existing => widget.repository.courses
      .where(
        (c) =>
            c.semesterId == _semesterId &&
            c.code.trim().toUpperCase() == _code.text.trim().toUpperCase(),
      )
      .firstOrNull;
  bool _alreadyImported(_AssessmentInput row) => widget.repository.tasks.any(
    (t) =>
        t.courseId == _existing?.id &&
        t.source?.fingerprint == row.draft.source.fingerprint &&
        t.source?.rowId == row.draft.source.rowId,
  );

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _deadline(_AssessmentInput row) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: row.deadline ?? widget.clock.now(),
      currentDate: widget.clock.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && mounted) {
      setState(
        () => row.deadline = DateTime(
          selected.year,
          selected.month,
          selected.day,
          row.deadline?.hour ?? 23,
          row.deadline?.minute ?? 59,
        ),
      );
    }
  }

  Future<void> _time(_AssessmentInput row) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(row.deadline!),
    );
    if (selected != null && mounted) {
      setState(() {
        final d = row.deadline!;
        row.deadline = DateTime(
          d.year,
          d.month,
          d.day,
          selected.hour,
          selected.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid =
        _courseForm.currentState!.validate() &&
        _assessmentForm.currentState!.validate();
    final selected = _rows
        .where((r) => r.selected && !_alreadyImported(r))
        .toList();
    if (!valid || !_confirmed || selected.any(_incompleteAssessment)) {
      setState(
        () => _error = 'Check the selected assessments and confirm the review.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = 'import-${DateTime.now().microsecondsSinceEpoch}';
      final course = AcademicCourse(
        id: id,
        semesterId: _semesterId,
        code: _code.text.trim().toUpperCase(),
        name: _existing?.name ?? _name.text.trim(),
        source: widget.draft.courseSource,
        weeklyLearning: [
          for (var i = 0; i < _weeklyRows.length; i++)
            ReviewedWeeklyLearning(
              printed: widget.draft.weeklyLearning[i],
              confirmed: _weeklyRows[i],
            ),
        ],
      );
      final tasks = selected
          .map(
            (r) => AcademicTask(
              id: '$id-${r.draft.source.rowId}',
              title: r.title.text.trim(),
              subject: course.label,
              description: '',
              deadline: r.deadline,
              estimatedMinutes: int.parse(r.minutes.text),
              courseId: id,
              source: r.draft.source,
              assessmentWeightPercent: double.tryParse(r.weight.text.trim()),
            ),
          )
          .toList();
      final result = await widget.repository.importProforma(course, tasks);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Course confirmed · ${result.addedTasks} tasks added${result.addedWeeklyEntries > 0 ? ' · ${result.addedWeeklyEntries} weekly entries added' : ''}${result.skippedTasks > 0 ? ' · ${result.skippedTasks} existing tasks kept' : ''}${result.skippedWeeklyEntries > 0 ? ' · saved weekly entries kept' : ''}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = academicSaveError(error);
        });
      }
    }
  }

  List<_AssessmentInput> get _selected =>
      _rows.where((row) => row.selected && !_alreadyImported(row)).toList();

  void _back() {
    if (_saving) return;
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _step--;
        _error = null;
        _confirmed = false;
      });
    }
  }

  // Validate controller values too: offscreen list fields may not be mounted.
  bool _incompleteAssessment(_AssessmentInput row) {
    final minutes = int.tryParse(row.minutes.text);
    final weight = double.tryParse(row.weight.text.trim());
    return row.title.text.trim().isEmpty ||
        (row.weight.text.trim().isNotEmpty &&
            (weight == null ||
                !weight.isFinite ||
                weight < 0 ||
                weight > 100)) ||
        validateEffort(minutes) != null;
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    if (_step == 0 && !_courseForm.currentState!.validate()) return;
    if (_step == 1) {
      final valid = _assessmentForm.currentState!.validate();
      if (!valid || _selected.any(_incompleteAssessment)) {
        setState(
          () => _error =
              'Each selected assessment needs a title and a time estimate.',
        );
        return;
      }
    }
    setState(() {
      _step++;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && _step == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving && _step > 0) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Review proforma'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _saving ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('STEP ${_step + 1} OF 3 · NOTHING SAVED YET'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: i <= _step
                                            ? planovaActionOrange
                                            : planovaBorder,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      ['Course', 'Assessments', 'Confirm'][i],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: i == _step
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: i == _step
                                            ? planovaInk
                                            : planovaMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _step,
                    children: [
                      _courseStep(),
                      _assessmentStep(),
                      _confirmationStep(),
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
                        onPressed: _saving
                            ? null
                            : (_step == 2 ? _save : _continue),
                        child: Text(
                          _saving
                              ? 'Saving…'
                              : _step == 2
                              ? 'Save reviewed import'
                              : _step == 0
                              ? 'Continue to assessments'
                              : 'Review import',
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

  Widget _courseStep() => Form(
    key: _courseForm,
    child: ListView(
      key: const PageStorageKey('import-course-step'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _heading('Make it your course.'),
        const SizedBox(height: 8),
        const Text(
          'Check the extracted details before choosing tasks.',
          style: TextStyle(color: planovaMuted, height: 1.5),
        ),
        const SizedBox(height: 20),
        Text(
          widget.draft.courseSource.fileName,
          style: const TextStyle(color: planovaMuted),
        ),
        if (widget.draft.documentSession != null)
          Text(
            'Document: ${widget.draft.documentSession}',
            style: const TextStyle(height: 1.5),
          ),
        if (widget.draft.warnings.isNotEmpty)
          ExpansionTile(
            key: const PageStorageKey('import-extraction-notes'),
            tilePadding: EdgeInsets.zero,
            title: Text('Extraction notes (${widget.draft.warnings.length})'),
            children: [
              for (final warning in widget.draft.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    warning,
                    style: const TextStyle(color: planovaMuted, height: 1.5),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _semesterId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Save to semester'),
          items: widget.repository.semesters
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) => setState(() => _semesterId = value!),
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: const ValueKey('import-code'),
          controller: _code,
          enabled: !_saving,
          maxLength: 30,
          decoration: const InputDecoration(labelText: 'Course code'),
          onChanged: (_) => setState(() {}),
          validator: _required,
        ),
        const SizedBox(height: 12),
        if (_existing == null)
          TextFormField(
            key: const ValueKey('import-name'),
            controller: _name,
            enabled: !_saving,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Course name'),
            validator: _required,
          ),
        if (_existing != null)
          Panel(
            child: Text(
              '${_existing!.label} already exists in this semester. Its name, tasks and saved weekly corrections will be kept. Only new source rows will be added; weekly records from another PDF version will not replace saved entries.',
              style: const TextStyle(height: 1.5),
            ),
          ),
        if (widget.draft.weeklyLearning.isNotEmpty) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving ? null : _reviewWeekly,
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(
              'View weekly learning (${widget.draft.weeklyLearning.length})',
            ),
          ),
        ],
        ProformaSourceEvidence(source: widget.draft.courseSource),
      ],
    ),
  );

  Widget _assessmentStep() => Form(
    key: _assessmentForm,
    child: ListView(
      key: const PageStorageKey('import-assessment-step'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _heading('Check the assessments.'),
        const SizedBox(height: 8),
        const Text(
          'All assessments are selected. Untick any you do not want. Time estimates come from the proforma where printed. Due dates are optional: add them now or later.',
          style: TextStyle(color: planovaMuted, height: 1.5),
        ),
        const SizedBox(height: 12),
        Text(
          '${_selected.length} selected',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < _rows.length; i++) _assessment(_rows[i], i),
      ],
    ),
  );

  Widget _confirmationStep() => ListView(
    key: const PageStorageKey('import-confirm-step'),
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    children: [
      _heading('Ready to save?'),
      const SizedBox(height: 8),
      const Text(
        'One final check. Go back any time to make changes.',
        style: TextStyle(color: planovaMuted, height: 1.5),
      ),
      const SizedBox(height: 24),
      FeaturedPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _code.text.trim().toUpperCase(),
              style: const TextStyle(
                color: planovaOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _existing?.name ?? _name.text.trim(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              widget.repository.semesters
                  .firstWhere((s) => s.id == _semesterId)
                  .name,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            if (_selected.any((row) => row.deadline == null))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_selected.where((row) => row.deadline == null).length} without a due date yet · add them later',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            Text(
              '${_selected.length} new ${_selected.length == 1 ? 'task' : 'tasks'} · ${formatDuration(_selected.fold<int>(0, (sum, row) => sum + (int.tryParse(row.minutes.text) ?? 0)))} remaining',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (_selected.isEmpty)
        Text(
          _newWeeklyCount == 0
              ? 'Only the course will be saved. No new tasks will be added.'
              : 'The course and $_newWeeklyCount weekly entries will be saved. No new tasks will be added.',
          style: const TextStyle(height: 1.5),
        ),
      if (widget.draft.weeklyLearning.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '$_newWeeklyCount new weekly entries. Existing weekly corrections are kept. Unknown NF2F values remain unknown.',
          ),
        ),
      for (final row in _selected)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title.text.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  row.deadline == null
                      ? 'No due date yet · add it later'
                      : 'Due ${row.deadline!.day} ${months[row.deadline!.month - 1]} ${row.deadline!.year} · ${TimeOfDay.fromDateTime(row.deadline!).format(context)}',
                  style: const TextStyle(color: planovaMuted, height: 1.5),
                ),
                Text(
                  '${formatDuration(int.tryParse(row.minutes.text) ?? 0)} of work',
                  style: const TextStyle(color: planovaMuted, height: 1.5),
                ),
                Text(
                  row.weight.text.trim().isEmpty
                      ? 'Assessment weight unknown · not eligible for ranking yet'
                      : '${row.weight.text.trim()}% of course grade',
                  style: const TextStyle(color: planovaMuted, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      if (_rows.any(_alreadyImported))
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Previously imported tasks will be kept without duplicates.',
            style: TextStyle(color: planovaMuted, height: 1.5),
          ),
        ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _confirmed,
        onChanged: _saving
            ? null
            : (value) => setState(() => _confirmed = value!),
        title: Text(
          widget.draft.weeklyLearning.isEmpty
              ? 'I reviewed the course and selected assessments.'
              : 'I reviewed the course, weekly learning and selected assessments.',
        ),
        activeColor: planovaActionOrange,
        checkColor: planovaOnOrange,
      ),
    ],
  );

  Widget _heading(String text) => Text(
    text,
    style: Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800),
  );

  Widget _assessment(_AssessmentInput row, int index) {
    final imported = _alreadyImported(row);
    final source = row.draft.source;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${source.rowId} · PDF page ${source.page}',
              style: const TextStyle(color: planovaMuted, fontSize: 12),
            ),
            CheckboxListTile(
              key: ValueKey('import-select-$index'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(row.draft.title),
              subtitle: Text(
                imported
                    ? 'Already imported · existing task kept'
                    : 'Document weight: ${source.assessmentWeight}%',
              ),
              value: imported || row.selected,
              activeColor: planovaActionOrange,
              checkColor: planovaOnOrange,
              onChanged: _saving || imported
                  ? null
                  : (value) => setState(() => row.selected = value!),
            ),
            if (row.selected && !imported) ...[
              const SizedBox(height: 8),
              EffortField(
                fieldKey: 'import-minutes-$index',
                controller: row.minutes,
                enabled: !_saving,
                label: 'Time needed',
                helper:
                    row.draft.sltHours != null &&
                        _AssessmentInput.suggestedMinutes(row.draft) != null
                    ? 'Suggested from the proforma: ${formatDuration(_AssessmentInput.suggestedMinutes(row.draft)!)} of study time. Change it if your estimate differs.'
                    : 'The proforma has no hours for this assessment. Add your own estimate.',
                validate: validateEffort,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: ValueKey('import-date-$index'),
                    onPressed: _saving ? null : () => _deadline(row),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      row.deadline == null
                          ? 'Add due date (optional)'
                          : 'Due ${row.deadline!.day} ${months[row.deadline!.month - 1]} ${row.deadline!.year}',
                    ),
                  ),
                  if (row.deadline != null) ...[
                    TextButton(
                      onPressed: _saving ? null : () => _time(row),
                      child: Text(
                        'Time: ${TimeOfDay.fromDateTime(row.deadline!).format(context)}',
                      ),
                    ),
                    TextButton(
                      key: ValueKey('import-clear-date-$index'),
                      onPressed: _saving
                          ? null
                          : () => setState(() => row.deadline = null),
                      child: const Text('Decide later'),
                    ),
                  ],
                ],
              ),
              if (row.deadline == null)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Due dates are not in the proforma. You can add it later from the task.',
                    style: TextStyle(color: planovaMuted, fontSize: 13),
                  ),
                ),
              // A plain toggle (not ExpansionTile) so nothing shares
              // PageStorage slots with the list's scroll position.
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: ValueKey('import-edit-$index'),
                  onPressed: () =>
                      setState(() => row.editDetails = !row.editDetails),
                  icon: Icon(
                    row.editDetails
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  label: const Text('Edit title or grade weight'),
                ),
              ),
              if (row.editDetails)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: ValueKey('import-title-$index'),
                      controller: row.title,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                      ),
                      maxLength: 100,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey('import-weight-$index'),
                      controller: row.weight,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Grade weight (%)',
                        helperText: 'Read from the proforma. Correct it if needed, or leave blank if unknown.',
                        helperMaxLines: 4,
                        errorMaxLines: 3,
                      ),
                      validator: (text) {
                        if (text == null || text.trim().isEmpty) return null;
                        final value = double.tryParse(text.trim());
                        return value == null ||
                                !value.isFinite ||
                                value < 0 ||
                                value > 100
                            ? 'Enter 0–100, or leave blank if unknown.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
            ],
            ProformaSourceEvidence(source: source),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}
