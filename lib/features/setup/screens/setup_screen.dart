import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/academic_course.dart';
import '../../../models/weekly_availability.dart';
import '../../../services/planning/free_study_slots.dart';
import '../../availability/screens/availability_screen.dart';
import '../../availability/screens/time_block_form.dart';
import '../../courses/screens/academic_record_form.dart';
import '../../courses/screens/proforma_import_screen.dart';

/// The semester Planova sets up and imports into: the one containing today,
/// otherwise the one that started most recently.
AcademicSemester? currentSemester(TaskRepository repository, DateTime now) {
  final day = DateUtils.dateOnly(now);
  final semesters = [...repository.semesters]
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  return semesters
          .where((s) => !day.isBefore(s.startDate) && !day.isAfter(s.endDate))
          .firstOrNull ??
      semesters.firstOrNull;
}

/// A ready-made weekly study window the student can switch on with one tap.
/// Each preset is saved as a normal study window with a fixed ID, so it can
/// be edited or removed later on the Weekly availability screen.
class AvailabilityPreset {
  const AvailabilityPreset(
    this.id,
    this.label,
    this.days,
    this.start,
    this.end,
  );
  final String id;
  final String label;
  final List<int> days;
  final int start;
  final int end;

  WeeklyTimeRange get range =>
      WeeklyTimeRange(weekdays: days, startMinute: start, endMinute: end);
  String get detail =>
      '${formatWeekdays(days)}, ${formatClock(start)}–${formatClock(end)}';

  static const all = [
    AvailabilityPreset(
      'preset-weekday-evenings',
      'Weekday evenings',
      [1, 2, 3, 4, 5],
      20 * 60,
      22 * 60,
    ),
    AvailabilityPreset(
      'preset-weekday-afternoons',
      'Weekday afternoons',
      [1, 2, 3, 4, 5],
      14 * 60,
      17 * 60,
    ),
    AvailabilityPreset(
      'preset-weekend-mornings',
      'Weekend mornings',
      [6, 7],
      9 * 60,
      12 * 60,
    ),
  ];
}

/// Guided first-run setup: semester → courses → weekly availability.
///
/// Every step saves straight to the existing repositories, so leaving with
/// "Finish later" loses nothing, and reopening resumes at any step.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.tasks,
    required this.availability,
    required this.clock,
    this.initialStep = 0,
  });
  final TaskRepository tasks;
  final AvailabilityRepository availability;
  final AppClock clock;
  final int initialStep;

  /// The first step that still has nothing saved.
  static int firstIncompleteStep(
    TaskRepository tasks,
    AvailabilityRepository availability,
  ) {
    if (tasks.semesters.isEmpty) return 0;
    if (tasks.courses.isEmpty) return 1;
    return 2;
  }

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _stepNames = ['Semester', 'Courses', 'Availability'];
  late int _step = widget.initialStep.clamp(0, 2);

  // Step 1: inline semester form, used only when no semester exists yet.
  final _semesterForm = GlobalKey<FormState>();
  final _semesterName = TextEditingController();
  late DateTime _start = DateUtils.dateOnly(widget.clock.now());
  late DateTime _end = _start.add(const Duration(days: 120));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _semesterName.dispose();
    super.dispose();
  }

  AcademicSemester? get _semester =>
      currentSemester(widget.tasks, widget.clock.now());

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  Future<void> _next() async {
    if (_saving) return;
    if (_step == 0 && _semester == null) {
      if (!_semesterForm.currentState!.validate()) return;
      if (_end.isBefore(_start)) {
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
        await widget.tasks.saveSemester(
          AcademicSemester(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            name: _semesterName.text.trim(),
            startDate: _start,
            endDate: _end,
          ),
          isNew: true,
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
      setState(() => _saving = false);
    }
    if (_step == 2) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setup saved. Today lists anything still missing.'),
        ),
      );
      return;
    }
    setState(() {
      _step++;
      _error = null;
    });
  }

  String get _primaryLabel {
    if (_saving) return 'Saving…';
    if (_step == 0) return _semester == null ? 'Save and continue' : 'Continue';
    if (_step == 1) {
      final semester = _semester;
      final hasCourses =
          semester != null &&
          widget.tasks.courses.any((c) => c.semesterId == semester.id);
      return hasCourses ? 'Continue' : 'Skip for now';
    }
    return 'Finish setup';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _step == 0 && !_saving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving && _step > 0) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Set up Planova'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _saving ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            key: const ValueKey('setup-finish-later'),
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Finish later'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(
              listenable: Listenable.merge([widget.tasks, widget.availability]),
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _progress(),
                  Expanded(
                    child: switch (_step) {
                      0 => _semesterStep(),
                      1 => _coursesStep(),
                      _ => _availabilityStep(),
                    },
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
                          key: const ValueKey('setup-next'),
                          onPressed: _saving ? null : _next,
                          child: Text(_primaryLabel),
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
    ),
  );

  Widget _progress() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('STEP ${_step + 1} OF 3 · ${_stepNames[_step].toUpperCase()}'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= _step ? planovaActionOrange : planovaBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _intro(String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(body, style: const TextStyle(color: planovaMuted, height: 1.5)),
      const SizedBox(height: 24),
    ],
  );

  // ---- Step 1: semester -------------------------------------------------

  Widget _semesterStep() {
    final semester = _semester;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        _intro(
          'When is your semester?',
          'Planova uses these dates to organise your courses and weeks.',
        ),
        if (semester != null)
          Panel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        semester.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_date(semester.startDate)} – ${_date(semester.endDate)}',
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
                        semester: semester,
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
            key: _semesterForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('setup-semester-name'),
                  controller: _semesterName,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Semester name',
                    hintText: 'e.g. Semester 1 · 2026/2027',
                  ),
                  maxLength: 100,
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
      ],
    );
  }

  Widget _dateButton(
    String label,
    DateTime value,
    void Function(DateTime) set,
  ) => OutlinedButton.icon(
    onPressed: _saving
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

  static String _date(DateTime d) =>
      '${d.day} ${months[d.month - 1]} ${d.year}';

  // ---- Step 2: courses --------------------------------------------------

  Widget _coursesStep() {
    final semester = _semester;
    if (semester == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [_intro('Add your courses', 'Add your semester first.')],
      );
    }
    final courses = widget.tasks.courses
        .where((course) => course.semesterId == semester.id)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        _intro(
          'Add your courses',
          'Import each course proforma (PDF). Planova reads the assessments and their study hours for you.',
        ),
        for (final course in courses) _courseRow(course),
        if (courses.isNotEmpty) const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('setup-import'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ProformaImportScreen(
                repository: widget.tasks,
                clock: widget.clock,
                semesterId: semester.id,
              ),
            ),
          ),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(
            courses.isEmpty ? 'Import a proforma' : 'Import another proforma',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('setup-add-course'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AcademicRecordForm(
                repository: widget.tasks,
                clock: widget.clock,
                semesterId: semester.id,
              ),
            ),
          ),
          child: const Text('No PDF? Add a course yourself'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Missing due dates can be added later from Today.',
          textAlign: TextAlign.center,
          style: TextStyle(color: planovaMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _courseRow(AcademicCourse course) {
    final tasks = widget.tasks.tasks.where((t) => t.courseId == course.id);
    final missing = tasks.where((t) => !t.isCompleted && !t.hasDeadline).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tasks.length} ${tasks.length == 1 ? 'assessment' : 'assessments'}'
                    '${missing > 0 ? ' · $missing need a date' : ''}',
                    style: const TextStyle(color: planovaMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              missing > 0
                  ? Icons.event_busy_outlined
                  : Icons.check_circle_rounded,
              color: missing > 0 ? planovaMuted : planovaActionOrange,
            ),
          ],
        ),
      ),
    );
  }

  // ---- Step 3: availability --------------------------------------------

  Widget _availabilityStep() {
    final week = widget.availability.availability;
    final free = freeMinutesPerWeek(week);
    final presetIds = AvailabilityPreset.all.map((p) => p.id).toSet();
    final custom = week.windows.where((w) => !presetIds.contains(w.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        _intro(
          'When can you study?',
          'Pick what fits a normal week. You can fine-tune times later.',
        ),
        for (final preset in AvailabilityPreset.all) _presetTile(preset),
        _choiceTile(
          key: const ValueKey('setup-custom-times'),
          title: 'Custom times',
          detail: custom.isEmpty
              ? 'Choose days and times yourself'
              : '${custom.length} custom ${custom.length == 1 ? 'window' : 'windows'}',
          selected: custom.isNotEmpty,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  AvailabilityScreen(repository: widget.availability),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Fixed in your week',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Classes, clubs, work. Study is never planned over these.',
          style: TextStyle(color: planovaMuted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        for (final c in week.commitments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: planovaSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${c.title} · ${formatWeekdays(c.range.weekdays)} ${formatClock(c.range.startMinute)}–${formatClock(c.range.endMinute)}',
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('setup-add-commitment'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TimeBlockForm.commitment(widget.availability),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add commitment'),
          ),
        ),
        const SizedBox(height: 16),
        FeaturedPanel(
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Free for study each week',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Text(
                week.windows.isEmpty ? '—' : formatDuration(free),
                key: const ValueKey('setup-free-time'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _presetTile(AvailabilityPreset preset) {
    final on = widget.availability.availability.windows.any(
      (w) => w.id == preset.id,
    );
    return _choiceTile(
      key: ValueKey(preset.id),
      title: preset.label,
      detail: preset.detail,
      selected: on,
      trailing: Icon(
        on ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: on ? planovaActionOrange : planovaMuted,
      ),
      onTap: () async {
        try {
          if (on) {
            await widget.availability.deleteWindow(preset.id);
          } else {
            await widget.availability.saveWindow(
              StudyWindow(id: preset.id, range: preset.range),
            );
          }
        } catch (error) {
          if (mounted) setState(() => _error = academicSaveError(error));
        }
      },
    );
  }

  Widget _choiceTile({
    required Key key,
    required String title,
    required String detail,
    required bool selected,
    required Widget trailing,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      selected: selected,
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
          key: key,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
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
                const SizedBox(width: 12),
                trailing,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
