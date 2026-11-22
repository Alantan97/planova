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
import '../../../models/study_preferences.dart';
import '../../availability/widgets/availability_summary_card.dart';
import '../../courses/screens/courses_screen.dart';
import 'study_preferences_screen.dart';

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
    this.onClearData,
  });
  final ProfileRepository profile;
  final AuthService auth;
  final TaskRepository tasks;
  final AvailabilityRepository availability;
  final AppClock clock;

  /// Development only (debug builds): wipes all saved data and restarts.
  final Future<void> Function()? onClearData;

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
          const SectionTitle('Study preferences'),
          const SizedBox(height: 18),
          _StudyPreferencesCard(
            preferences: progress.preferences,
            onChange: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => StudyPreferencesScreen(profile: profile),
              ),
            ),
          ),
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
          const SizedBox(height: 12),
          Panel(
            child: SwitchListTile(
              key: const ValueKey('experimental-switch'),
              contentPadding: EdgeInsets.zero,
              value: progress.showExperimental,
              activeThumbColor: planovaOnOrange,
              activeTrackColor: planovaActionOrange,
              onChanged: (on) =>
                  profile.save(progress.copyWith(showExperimental: on)),
              title: const Text(
                'Experimental features',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Shows the task priority ranking (a research model that is '
                  'not validated yet) and weekly learning topics from '
                  'proformas. Planning does not use either.',
                  style: TextStyle(color: planovaMuted, height: 1.4),
                ),
              ),
            ),
          ),
          if (onClearData != null) ...[
            const SizedBox(height: 28),
            const SectionTitle('Developer'),
            const SizedBox(height: 18),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug builds only. Deletes every task, course, semester, '
                    'weekly availability, plan and profile setting on this '
                    'device, then starts again at the welcome screen.',
                    style: TextStyle(color: planovaMuted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const ValueKey('clear-data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => _confirmClear(context),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Clear all data'),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'Everything saved on this device will be deleted. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-clear-data'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onClearData!();
  }

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

/// The student's study preferences in plain words, with a way to change
/// them. The planner follows exactly these.
class _StudyPreferencesCard extends StatelessWidget {
  const _StudyPreferencesCard({
    required this.preferences,
    required this.onChange,
  });
  final StudyPreferences preferences;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final p = preferences;
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
    final daysOff = [
      for (var d = 1; d <= 7; d++)
        if (p.daysOff.contains(d)) weekdays[d - 1],
    ];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          rule(
            Icons.timer_outlined,
            'Sessions of ${formatDuration(p.minSessionMinutes)}–'
            '${formatDuration(p.maxSessionMinutes)}',
          ),
          rule(
            Icons.free_breakfast_outlined,
            p.breakMinutes == 0
                ? 'No break between sessions'
                : '${formatDuration(p.breakMinutes)} break between sessions',
          ),
          rule(
            Icons.today_outlined,
            'Up to ${formatDuration(p.dailyLimitMinutes)} of study a day',
          ),
          rule(
            Icons.layers_outlined,
            'Up to ${formatDuration(p.perTaskDailyMinutes)} on one task a day',
          ),
          rule(
            Icons.weekend_outlined,
            daysOff.isEmpty ? 'No days off' : 'Days off: ${daysOff.join(', ')}',
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            key: const ValueKey('open-preferences'),
            onPressed: onChange,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Change preferences'),
          ),
        ],
      ),
    );
  }
}
