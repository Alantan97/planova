import 'package:flutter/material.dart';

import '../../app/app_dependencies.dart';
import '../../core/errors/academic_save_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/date_time_helpers.dart';
import '../../core/widgets/study_components.dart';
import '../../models/onboarding_progress.dart';
import '../../services/auth/auth_service.dart';
import '../../services/planning/rule_based_planner.dart';
import '../planner/widgets/plan_action_card.dart';
import '../setup/screens/setup_screen.dart';
import '../setup/widgets/setup_steps.dart';
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
        currentSemester(_d.tasks, now) == null
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
    if (_step == 0) return _welcome();
    if (_step == 1) {
      return _IntroCards(onDone: () => _goTo(2), onBack: () => _goTo(0));
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

  // ---- 0 · Welcome & account ---------------------------------------------

  // Scrolls on small screens or with large text; when there is room the
  // spacers still spread the content over the screen.
  Widget _welcome() => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: IntrinsicHeight(child: _welcomeContent()),
          ),
        ),
      ),
    ),
  );

  Widget _welcomeContent() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                label: 'Planova logo',
                image: true,
                child: Image.asset(
                  'assets/branding/planova_wordmark_black.png',
                  height: 28,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const Spacer(),
            const Text(
              'Plan your semester, one week at a time.',
              style: TextStyle(
                fontSize: 32,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Import your course proformas, tell Planova when you can study, and get a weekly plan you can adjust.',
              style: TextStyle(color: planovaMuted, fontSize: 16, height: 1.5),
            ),
            const Spacer(),
            OutlinedButton.icon(
              key: const ValueKey('onboarding-google'),
              onPressed: _busy ? null : _google,
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('onboarding-guest'),
              onPressed: _busy ? null : _continueAsGuest,
              child: const Text('Continue without an account'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Google sign-in is not connected yet. Your data stays on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: planovaMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );

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
        if (waiting.isEmpty)
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
    final proposal = planWeek(
      tasks: _d.tasks.tasks,
      availability: _d.availability.availability,
      now: _d.clock.now(),
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
          Text(
            proposal.sessions.isNotEmpty
                ? 'Open it to see each day, then accept or cancel.'
                : !proposal.hasAvailability
                ? 'Add study times in the previous step to get a plan.'
                : 'Add due dates and time estimates to your assessments to get a plan.',
            style: const TextStyle(color: planovaMuted, height: 1.5),
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

/// Step 1: three short cards explaining the idea, swipe or tap Next.
class _IntroCards extends StatefulWidget {
  const _IntroCards({required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<_IntroCards> createState() => _IntroCardsState();
}

class _IntroCardsState extends State<_IntroCards> {
  final _pages = PageController();
  int _page = 0;

  static const _cards = [
    (
      Icons.upload_file_outlined,
      'Import your courses',
      'Pick a course proforma PDF. Planova reads its assessments, grade weights and study hours.',
    ),
    (
      Icons.event_note_outlined,
      'Get a weekly plan',
      'Tell Planova when you can study. It fills that time with sessions, earliest due date first.',
    ),
    (
      Icons.published_with_changes_rounded,
      'Record and adjust',
      'Mark each session done, partly done or missed. If plans change, re-plan the rest of the week.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: widget.onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        TextButton(
          key: const ValueKey('onboarding-intro-skip'),
          onPressed: widget.onDone,
          child: const Text('Skip'),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    for (final (icon, title, body) in _cards)
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4EC),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                icon,
                                size: 36,
                                color: planovaActionOrange,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              body,
                              style: const TextStyle(
                                color: planovaMuted,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Semantics(
                label: 'Card ${_page + 1} of ${_cards.length}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _cards.length; i++)
                      Container(
                        width: i == _page ? 22 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _page
                              ? planovaActionOrange
                              : planovaBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('onboarding-intro-next'),
                    onPressed: () {
                      if (_page == _cards.length - 1) {
                        widget.onDone();
                      } else {
                        _pages.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Text(
                      _page == _cards.length - 1 ? 'Get started' : 'Next',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
