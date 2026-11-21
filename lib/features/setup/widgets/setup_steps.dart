import 'package:flutter/material.dart';

import '../../../core/widgets/near_limit_counter.dart';
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
import '../../tasks/screens/task_form_screen.dart';

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

/// Heading and short explanation at the top of a step.
class StepIntro extends StatelessWidget {
  const StepIntro(this.title, this.body, {super.key});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
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
}

String _date(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';

// ---- Semester -------------------------------------------------------------

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
      currentSemester(widget.tasks, widget.clock.now());

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

// ---- Courses --------------------------------------------------------------

/// The semester's courses with import / add-course actions.
class CoursesStep extends StatelessWidget {
  const CoursesStep({super.key, required this.tasks, required this.clock});
  final TaskRepository tasks;
  final AppClock clock;

  /// Whether the current semester has at least one course.
  static bool hasCourses(TaskRepository tasks, DateTime now) {
    final semester = currentSemester(tasks, now);
    return semester != null &&
        tasks.courses.any((c) => c.semesterId == semester.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tasks,
    builder: (context, _) {
      final semester = currentSemester(tasks, clock.now());
      if (semester == null) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: const [
            StepIntro('Add your courses', 'Add your semester first.'),
          ],
        );
      }
      final courses = tasks.courses
          .where((course) => course.semesterId == semester.id)
          .toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          const StepIntro(
            'Add your courses',
            'Import each course proforma (PDF). Planova reads the assessments and their study hours for you.',
          ),
          for (final course in courses) _courseRow(context, course),
          if (courses.isNotEmpty) const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('setup-import'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProformaImportScreen(
                  repository: tasks,
                  clock: clock,
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
                  repository: tasks,
                  clock: clock,
                  semesterId: semester.id,
                ),
              ),
            ),
            child: const Text('No PDF? Add a course yourself'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Missing due dates can be added in the next steps or later from Today.',
            textAlign: TextAlign.center,
            style: TextStyle(color: planovaMuted, fontSize: 13),
          ),
        ],
      );
    },
  );

  /// A course is only "done" here once it has assessments. A course added by
  /// hand starts empty, so it offers "Add assessment" instead of a tick.
  Widget _courseRow(BuildContext context, AcademicCourse course) {
    final linked = tasks.tasks.where((t) => t.courseId == course.id);
    final missing = linked
        .where((t) => !t.isCompleted && !t.hasDeadline)
        .length;
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
                    linked.isEmpty
                        ? 'No assessments yet'
                        : '${linked.length} ${linked.length == 1 ? 'assessment' : 'assessments'}'
                              '${missing > 0 ? ' · $missing need a date' : ''}',
                    style: TextStyle(
                      color: linked.isEmpty
                          ? const Color(0xFF8F3300)
                          : planovaMuted,
                      fontSize: 13,
                      fontWeight: linked.isEmpty
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  if (linked.isNotEmpty)
                    TextButton.icon(
                      key: ValueKey('setup-more-assessment-${course.id}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => _addAssessment(context, course),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add another assessment'),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (linked.isEmpty)
              FilledButton.tonal(
                key: ValueKey('setup-add-assessment-${course.id}'),
                onPressed: () => _addAssessment(context, course),
                child: const Text('Add assessment'),
              )
            else
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

  void _addAssessment(BuildContext context, AcademicCourse course) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TaskFormScreen(
            repository: tasks,
            clock: clock,
            initialCourseId: course.id,
          ),
        ),
      );
}

// ---- Availability ---------------------------------------------------------

/// One-tap presets, custom times and commitments, with the weekly total.
class AvailabilityStep extends StatelessWidget {
  const AvailabilityStep({super.key, required this.availability});
  final AvailabilityRepository availability;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: availability,
    builder: (context, _) {
      final week = availability.availability;
      final free = freeMinutesPerWeek(week);
      final presetIds = AvailabilityPreset.all.map((p) => p.id).toSet();
      final custom = week.windows.where((w) => !presetIds.contains(w.id));
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          const StepIntro(
            'When can you study?',
            'Pick what fits a normal week. You can fine-tune times later.',
          ),
          for (final preset in AvailabilityPreset.all)
            _presetTile(context, preset),
          _ChoiceTile(
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
                builder: (_) => AvailabilityScreen(repository: availability),
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
                  builder: (_) => TimeBlockForm.commitment(availability),
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
    },
  );

  Widget _presetTile(BuildContext context, AvailabilityPreset preset) {
    final on = availability.availability.windows.any((w) => w.id == preset.id);
    return _ChoiceTile(
      key: ValueKey(preset.id),
      title: preset.label,
      detail: preset.detail,
      selected: on,
      trailing: Icon(
        on ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: on ? planovaActionOrange : planovaMuted,
      ),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          if (on) {
            await availability.deleteWindow(preset.id);
          } else {
            await availability.saveWindow(
              StudyWindow(id: preset.id, range: preset.range),
            );
          }
        } catch (error) {
          messenger.showSnackBar(
            SnackBar(content: Text(academicSaveError(error))),
          );
        }
      },
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.title,
    required this.detail,
    required this.selected,
    required this.trailing,
    required this.onTap,
  });
  final String title;
  final String detail;
  final bool selected;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
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
