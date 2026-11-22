import 'package:flutter/material.dart';

import '../../core/widgets/near_limit_counter.dart';
import '../../app/app_dependencies.dart';
import '../../core/errors/academic_save_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/date_time_helpers.dart';
import '../../core/widgets/study_components.dart';
import '../../models/onboarding_progress.dart';
import '../../services/auth/auth_service.dart';
import '../../services/planning/rule_based_planner.dart';
import '../planner/open_plan_proposal.dart';
import 'widgets/availability_step.dart';
import 'widgets/courses_step.dart';
import 'widgets/semester_step.dart';
import 'widgets/step_intro.dart';
import 'widgets/step_progress.dart';
import 'widgets/fix_panel.dart';
import 'widgets/intro_cards.dart';
import 'widgets/welcome_screen.dart';
import '../today/widgets/needs_input_section.dart';

/// The guided first-run journey, one screen at a time:
///
/// 0 welcome & account · 1 how Planova works · 2 about you · 3 semester ·
/// 4 courses · 5 your week · 6 missing due dates · 7 first plan · 8 done.
///
/// Progress is saved after every step, so "Finish later" (or closing the app)
/// resumes at the same screen. Everything entered is saved immediately by the
/// same repositories the rest of the app uses.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.dependencies});
  final AppDependencies dependencies;

  static const lastStep = 8;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  AppDependencies get _d => widget.dependencies;
  late int _step = _d.profile.progress.step.clamp(0, OnboardingFlow.lastStep);
  final _semester = GlobalKey<SemesterStepState>();
  late final _name = TextEditingController(
    text: _d.profile.progress.displayName ?? '',
  );
  bool _busy = false;
  String? _error;

  static const _titles = {
    2: 'About you',
    3: 'Semester',
    4: 'Courses',
    5: 'Your week',
    6: 'Due dates',
    7: 'First plan',
    8: 'All set',
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(OnboardingProgress progress) async {
    try {
      await _d.profile.save(progress);
    } catch (error) {
      if (mounted) setState(() => _error = academicSaveError(error));
      rethrow;
    }
  }

  Future<void> _goTo(int step) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _save(_d.profile.progress.copyWith(step: step));
      if (mounted) setState(() => _step = step);
    } catch (_) {
      // _save already showed the error.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsGuest() async {
    await _save(
      _d.profile.progress.copyWith(accountType: AccountType.guest, step: 1),
    );
    if (mounted) setState(() => _step = 1);
  }

  Future<void> _google() async {
    try {
      final user = await _d.auth.signInWithGoogle();
      await _save(
        _d.profile.progress.copyWith(
          accountType: AccountType.google,
          displayName: user.displayName,
          step: 1,
        ),
      );
      if (mounted) setState(() => _step = 1);
    } on GoogleSignInUnavailable catch (notice) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Google sign-in is coming'),
          content: Text('$notice'),
          actions: [
            FilledButton(
              key: const ValueKey('google-unavailable-ok'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue without an account'),
            ),
          ],
        ),
      );
      await _continueAsGuest();
    }
  }

  /// "Finish later": leave the journey for Today. The step is kept so
  /// "Continue guided setup" on Today resumes here.
  Future<void> _finishLater() =>
      _save(_d.profile.progress.copyWith(completed: true));

  Future<void> _finish() =>
      _save(_d.profile.progress.copyWith(completed: true, step: 0));

  Future<void> _next() async {
    if (_busy) return;
    switch (_step) {
      case 2:
        final name = _name.text.trim();
        await _save(
          name.isEmpty
              ? _d.profile.progress.copyWith(clearName: true)
              : _d.profile.progress.copyWith(displayName: name),
        );
      case 3:
        setState(() => _busy = true);
        final ok = await _semester.currentState!.submit();
        if (mounted) setState(() => _busy = false);
        if (!ok) return;
      case 8:
        await _finish();
        return;
    }
    await _goTo(_step + 1);
  }

  String get _nextLabel {
    final now = _d.clock.now();
    return switch (_step) {
      2 => _name.text.trim().isEmpty ? 'Skip' : 'Continue',
      3 =>
        _d.tasks.currentSemester(now) == null
            ? 'Save and continue'
            : 'Continue',
      4 => CoursesStep.hasCourses(_d.tasks, now) ? 'Continue' : 'Skip for now',
      5 =>
        _d.availability.availability.windows.isEmpty
            ? 'Skip for now'
            : 'Continue',
      6 =>
        NeedsInputSection.waiting(_d.tasks).isEmpty
            ? 'Continue'
            : 'Skip for now',
      7 => (_d.plans?.hasPlan ?? false) ? 'Continue' : 'Skip for now',
      _ => 'Go to Today',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return WelcomeScreen(
        busy: _busy,
        onGoogle: _google,
        onGuest: _continueAsGuest,
      );
    }
    if (_step == 1) {
      return IntroCards(onDone: () => _goTo(2), onBack: () => _goTo(0));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) _goTo(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _busy ? null : () => _goTo(_step - 1),
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            if (_step < OnboardingFlow.lastStep)
              TextButton(
                key: const ValueKey('onboarding-finish-later'),
                onPressed: _busy ? null : _finishLater,
                child: const Text('Finish later'),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  _d.tasks,
                  _d.availability,
                  ?_d.plans,
                ]),
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StepProgress(
                      label:
                          'STEP ${_step - 1} OF 7 · ${_titles[_step]!.toUpperCase()}',
                      current: _step - 2,
                      total: 7,
                    ),
                    Expanded(child: _body()),
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
                          // Skipping is allowed but should not look like
                          // the recommended action.
                          if (_nextLabel.startsWith('Skip') && !_busy)
                            OutlinedButton(
                              key: const ValueKey('onboarding-next'),
                              onPressed: _next,
                              child: Text(_nextLabel),
                            )
                          else
                            FilledButton(
                              key: const ValueKey('onboarding-next'),
                              onPressed: _busy ? null : _next,
                              child: Text(_busy ? 'Saving…' : _nextLabel),
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
  }

  Widget _body() => switch (_step) {
    2 => _aboutYou(),
    3 => SemesterStep(key: _semester, tasks: _d.tasks, clock: _d.clock),
    4 => CoursesStep(tasks: _d.tasks, clock: _d.clock),
    5 => AvailabilityStep(availability: _d.availability),
    6 => _missingDates(),
    7 => _firstPlan(),
    _ => _done(),
  };

  // ---- 2 · About you ------------------------------------------------------

  Widget _aboutYou() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    children: [
      const StepIntro(
        'What should we call you?',
        'Optional. Used to greet you on Today.',
      ),
      TextField(
        key: const ValueKey('onboarding-name'),
        controller: _name,
        decoration: const InputDecoration(labelText: 'Your name'),
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        buildCounter: nearLimitCounter,
        onChanged: (_) => setState(() {}),
      ),
    ],
  );

  // ---- 6 · Missing due dates ---------------------------------------------

  Widget _missingDates() {
    final waiting = NeedsInputSection.waiting(_d.tasks);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        const StepIntro(
          'Add missing due dates',
          'Proformas do not list due dates. Add the ones you know so Planova can plan them. You can do the rest later from Today.',
        ),
        if (_d.tasks.tasks.every((t) => t.isCompleted))
          FixPanel(
            message: 'You have no assessments yet, so there are no due dates to add.',
            action: 'Back to courses',
            buttonKey: 'onboarding-fix-dates',
            onPressed: () => _goTo(4),
          )
        else if (waiting.isEmpty)
          const Panel(
            child: Text(
              'Nothing missing. Every assessment has a due date.',
              style: TextStyle(height: 1.5),
            ),
          )
        else
          NeedsInputSection(repository: _d.tasks, clock: _d.clock),
      ],
    );
  }

  // ---- 7 · First plan ------------------------------------------------------

  Widget _firstPlan() {
    final plans = _d.plans;
    if (plans == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: const [
          StepIntro(
            'Your first plan',
            'Planning is not available in this demo build.',
          ),
        ],
      );
    }
    final settings = PlannerSettings.fromPreferences(
      _d.profile.progress.preferences,
    );
    final proposal = planWeek(
      tasks: _d.tasks.tasks,
      availability: _d.availability.availability,
      now: _d.clock.now(),
      settings: settings,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        const StepIntro(
          'Your first plan',
          'Planova fills your free study time for the next 7 days, earliest due date first. You review it before anything is saved.',
        ),
        if (plans.hasPlan)
          const Panel(
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: planovaActionOrange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Plan saved. You will see it on Today and Plan.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else ...[
          FeaturedPanel(
            child: Text(
              proposal.sessions.isEmpty
                  ? 'Nothing to plan yet'
                  : '${proposal.sessions.length} ${proposal.sessions.length == 1 ? 'session' : 'sessions'} · ${formatDuration(proposal.scheduledMinutes)} · ${proposal.taskCount} ${proposal.taskCount == 1 ? 'task' : 'tasks'}',
              key: const ValueKey('onboarding-plan-summary'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          if (proposal.sessions.isEmpty)
            _emptyPlanFix(proposal)
          else
            const Text(
              'Open it to see each day, then accept or cancel.',
              style: TextStyle(color: planovaMuted, height: 1.5),
            ),
          if (proposal.sessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey('onboarding-review-plan'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await openPlanProposal(
                  context,
                  plans: plans,
                  tasks: _d.tasks,
                  availability: _d.availability,
                  clock: _d.clock,
                  settings: settings,
                );
                // This step already says "Plan saved"; the snack bar would
                // only cover the Continue button.
                messenger.hideCurrentSnackBar();
              },
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('Review and accept'),
            ),
          ],
        ],
      ],
    );
  }

  /// Explains why nothing could be planned and links to the step that fixes
  /// it, checked in the order a student would fix them.
  Widget _emptyPlanFix(PlanProposal proposal) {
    final active = _d.tasks.tasks.where(
      (t) => !t.isCompleted && t.estimatedMinutes > t.completedMinutes,
    );
    final (message, action, step) = active.isEmpty
        ? ('There are no assessments to plan yet.', 'Add assessments', 4)
        : !proposal.hasAvailability
        ? ('Planova needs to know when you can study.', 'Choose study times', 5)
        : active.every((t) => !t.hasDeadline)
        ? (
            'Your assessments need due dates before they can be planned.',
            'Add due dates',
            6,
          )
        : (
            'Your free study time does not fit before the due dates. Add more study times, or check the due dates.',
            'Add study times',
            5,
          );
    return FixPanel(
      message: message,
      action: action,
      buttonKey: 'onboarding-fix-plan',
      onPressed: () => _goTo(step),
    );
  }

  // ---- 8 · Done ------------------------------------------------------------

  Widget _done() {
    final name = _d.profile.progress.displayName;
    Widget tip(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: planovaActionOrange),
          const SizedBox(width: 14),
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
                  body,
                  style: const TextStyle(color: planovaMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        StepIntro(
          name == null ? 'You are all set.' : 'You are all set, $name.',
          'Here is where to find things.',
        ),
        tip(
          Icons.wb_sunny_outlined,
          'Today',
          'Your next session, what needs your input, and what is due soon.',
        ),
        tip(
          Icons.school_outlined,
          'Courses',
          'Every assessment, grouped by course, with progress.',
        ),
        tip(
          Icons.calendar_month_outlined,
          'Plan',
          'Your week. Tap a session to record it; re-plan when things change.',
        ),
        tip(
          Icons.donut_large_rounded,
          'Progress',
          'Time studied against what you planned, and tasks completed.',
        ),
      ],
    );
  }
}
