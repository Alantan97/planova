import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../widgets/setup_steps.dart';

export '../widgets/setup_steps.dart' show currentSemester, AvailabilityPreset;

/// Short setup opened from Today's "Continue setup": semester → courses →
/// weekly availability. Uses the same step widgets as the first-run journey.
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
  final _semesterStep = GlobalKey<SemesterStepState>();
  bool _saving = false;

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _next() async {
    if (_saving) return;
    if (_step == 0) {
      setState(() => _saving = true);
      final ok = await _semesterStep.currentState!.submit();
      if (!mounted) return;
      setState(() => _saving = false);
      if (!ok) return;
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
    setState(() => _step++);
  }

  String get _primaryLabel {
    if (_saving) return 'Saving…';
    final now = widget.clock.now();
    if (_step == 0) {
      return currentSemester(widget.tasks, now) == null
          ? 'Save and continue'
          : 'Continue';
    }
    if (_step == 1) {
      return CoursesStep.hasCourses(widget.tasks, now)
          ? 'Continue'
          : 'Skip for now';
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
                  StepProgress(
                    label:
                        'STEP ${_step + 1} OF 3 · ${_stepNames[_step].toUpperCase()}',
                    current: _step,
                    total: 3,
                  ),
                  Expanded(
                    child: switch (_step) {
                      0 => SemesterStep(
                        key: _semesterStep,
                        tasks: widget.tasks,
                        clock: widget.clock,
                      ),
                      1 => CoursesStep(
                        tasks: widget.tasks,
                        clock: widget.clock,
                      ),
                      _ => AvailabilityStep(availability: widget.availability),
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: _primaryLabel.startsWith('Skip')
                        ? OutlinedButton(
                            key: const ValueKey('setup-next'),
                            onPressed: _next,
                            child: Text(_primaryLabel),
                          )
                        : FilledButton(
                            key: const ValueKey('setup-next'),
                            onPressed: _saving ? null : _next,
                            child: Text(_primaryLabel),
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

/// "STEP 2 OF 3 · COURSES" with a segmented progress bar.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.label,
    required this.current,
    required this.total,
  });
  final String label;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= current ? planovaActionOrange : planovaBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
