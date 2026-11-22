import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../core/widgets/near_limit_counter.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/onboarding_progress.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/planning/rule_based_planner.dart';
import '../../availability/widgets/availability_summary_card.dart';
import '../../courses/screens/courses_screen.dart';

/// The Profile tab: who you are, your semester and normal week, the rules the
/// planner follows, and an honest note on how plans are made.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.auth,
    required this.tasks,
    required this.availability,
    required this.clock,
  });
  final ProfileRepository profile;
  final AuthService auth;
  final TaskRepository tasks;
  final AvailabilityRepository availability;
  final AppClock clock;

  static const _nameLimit = 40;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: profile,
    builder: (context, _) {
      final progress = profile.progress;
      final name = progress.displayName?.trim();
      final hasName = name != null && name.isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Profile',
            subtitle: 'Your details, your week and how Planova plans.',
          ),
          const SizedBox(height: 20),
          FeaturedPanel(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: planovaOrange,
                  foregroundColor: planovaOnOrange,
                  child: hasName
                      ? Text(
                          name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : const Icon(Icons.person_outline_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasName ? name : 'Add your name',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _accountLine(progress.accountType),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('edit-name'),
                  tooltip: hasName ? 'Edit name' : 'Add name',
                  color: Colors.white,
                  onPressed: () => _editName(context, progress),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          if (!auth.googleSignInAvailable) ...[
            const SizedBox(height: 12),
            const Text(
              'Google sign-in is not connected yet, so there is no backup. '
              'Your data stays on this device.',
              style: TextStyle(color: planovaMuted, fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 28),
          const SectionTitle('Semester'),
          const SizedBox(height: 18),
          _semesterCard(context),
          const SizedBox(height: 28),
          const SectionTitle('My week'),
          const SizedBox(height: 18),
          AvailabilitySummaryCard(repository: availability),
          const SizedBox(height: 28),
          const SectionTitle('Study rules'),
          const SizedBox(height: 18),
          const _StudyRulesCard(settings: PlannerSettings()),
          const SizedBox(height: 28),
          const SectionTitle('About Planova'),
          const SizedBox(height: 18),
          const Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: planovaOrange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'How your plan is made',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Planova uses fixed, explainable rules, not trained AI. It '
                  'fills your free study time with the task due soonest first, '
                  'then the one worth more of your grade. You review every '
                  'plan before it is saved.',
                  style: TextStyle(color: planovaMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  static String _accountLine(AccountType type) => switch (type) {
    AccountType.google => 'Signed in with Google',
    _ => 'Guest · saved on this device',
  };

  Widget _semesterCard(BuildContext context) {
    final semester = tasks.currentSemester(clock.now());
    String date(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
    final courses = semester == null
        ? 0
        : tasks.courses.where((c) => c.semesterId == semester.id).length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: planovaOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  semester?.name ?? 'No semester yet',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            semester == null
                ? 'Add your semester so Planova knows your teaching weeks.'
                : '${date(semester.startDate)} – ${date(semester.endDate)} · '
                      '$courses ${courses == 1 ? 'course' : 'courses'}',
            style: const TextStyle(color: planovaMuted, height: 1.45),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const ValueKey('open-semesters'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CoursesScreen(repository: tasks, clock: clock),
              ),
            ),
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(
              semester == null ? 'Add semester' : 'Semesters and courses',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    OnboardingProgress progress,
  ) async {
    final controller = TextEditingController(text: progress.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          key: const ValueKey('profile-name'),
          controller: controller,
          autofocus: true,
          maxLength: _nameLimit,
          buildCounter: nearLimitCounter,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'What should we call you?',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('save-name'),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final name = result.trim();
    await profile.save(
      name.isEmpty
          ? progress.copyWith(clearName: true)
          : progress.copyWith(displayName: name),
    );
  }
}

/// The planner's rules, shown so students know what to expect. They are
/// fixed for now; making them adjustable is the next step.
class _StudyRulesCard extends StatelessWidget {
  const _StudyRulesCard({required this.settings});
  final PlannerSettings settings;

  @override
  Widget build(BuildContext context) {
    Widget rule(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: planovaMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          rule(
            Icons.timer_outlined,
            'Sessions of ${settings.minSessionMinutes}–'
            '${settings.maxSessionMinutes} min',
          ),
          rule(
            Icons.free_breakfast_outlined,
            '${settings.breakMinutes} min break between sessions',
          ),
          rule(
            Icons.today_outlined,
            'Up to ${formatDuration(settings.dailyLimitMinutes)} of study a day',
          ),
          rule(
            Icons.layers_outlined,
            'Up to ${formatDuration(settings.perTaskDailyMinutes)} on one task a day',
          ),
          const SizedBox(height: 2),
          const Text(
            'These are fixed for now. Changing them is coming next.',
            style: TextStyle(color: planovaMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
