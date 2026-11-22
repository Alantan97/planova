import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../models/study_preferences.dart';

/// Lets the student change how the planner fills their week. Saved with the
/// profile; the next plan or re-plan follows the new preferences.
class StudyPreferencesScreen extends StatefulWidget {
  const StudyPreferencesScreen({super.key, required this.profile});
  final ProfileRepository profile;

  @override
  State<StudyPreferencesScreen> createState() => _StudyPreferencesScreenState();
}

class _StudyPreferencesScreenState extends State<StudyPreferencesScreen> {
  late StudyPreferences _value = widget.profile.progress.preferences;
  bool _saving = false;
  String? _error;

  void _set(StudyPreferences value) => setState(() {
    _value = value;
    _error = null;
  });

  Future<void> _save() async {
    final problem = _value.problem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.profile.save(
        widget.profile.progress.copyWith(preferences: _value),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved. Your next plan or re-plan will follow them.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = academicSaveError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _value;
    final problem = v.problem;
    return Scaffold(
      appBar: AppBar(title: const Text('Study preferences')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                const Text(
                  'Planova fills your free study time using these. They '
                  'apply the next time you create or re-plan; a saved plan '
                  'stays as it is.',
                  style: TextStyle(color: planovaMuted, height: 1.5),
                ),
                _Section(
                  title: 'Shortest session',
                  hint: 'Free gaps shorter than this stay free.',
                  child: _Choices(
                    keyPrefix: 'pref-min',
                    values: StudyPreferences.minSessionChoices,
                    selected: v.minSessionMinutes,
                    enabled: (m) => m <= v.maxSessionMinutes,
                    onSelected: (m) => _set(v.copyWith(minSessionMinutes: m)),
                  ),
                ),
                _Section(
                  title: 'Longest session',
                  child: _Choices(
                    keyPrefix: 'pref-max',
                    values: StudyPreferences.maxSessionChoices,
                    selected: v.maxSessionMinutes,
                    enabled: (m) => m >= v.minSessionMinutes,
                    onSelected: (m) => _set(v.copyWith(maxSessionMinutes: m)),
                  ),
                ),
                _Section(
                  title: 'Break between sessions',
                  child: _Choices(
                    keyPrefix: 'pref-break',
                    values: StudyPreferences.breakChoices,
                    selected: v.breakMinutes,
                    label: (m) => m == 0 ? 'None' : formatDuration(m),
                    onSelected: (m) => _set(v.copyWith(breakMinutes: m)),
                  ),
                ),
                _Section(
                  title: 'Most study in a day',
                  child: _Choices(
                    keyPrefix: 'pref-daily',
                    values: StudyPreferences.dailyLimitChoices,
                    selected: v.dailyLimitMinutes,
                    enabled: (m) => m >= v.perTaskDailyMinutes,
                    onSelected: (m) => _set(v.copyWith(dailyLimitMinutes: m)),
                  ),
                ),
                _Section(
                  title: 'Most time on one task in a day',
                  hint: 'Long work is spread across days.',
                  child: _Choices(
                    keyPrefix: 'pref-task',
                    values: StudyPreferences.perTaskChoices,
                    selected: v.perTaskDailyMinutes,
                    enabled: (m) =>
                        m >= v.minSessionMinutes && m <= v.dailyLimitMinutes,
                    onSelected: (m) => _set(v.copyWith(perTaskDailyMinutes: m)),
                  ),
                ),
                _Section(
                  title: 'Days off',
                  hint: 'Nothing is planned on these days.',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          key: ValueKey('pref-off-$day'),
                          label: Text(weekdays[day - 1]),
                          tooltip: fullWeekdays[day - 1],
                          selected: v.daysOff.contains(day),
                          // Keep at least one study day.
                          onSelected:
                              !v.daysOff.contains(day) && v.daysOff.length == 6
                              ? null
                              : (on) => _set(
                                  v.copyWith(
                                    daysOff: on
                                        ? {...v.daysOff, day}
                                        : ({...v.daysOff}..remove(day)),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
                if (_error != null || problem != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error ?? problem!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('save-preferences'),
                  onPressed: _saving || problem != null ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save preferences'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('reset-preferences'),
                  onPressed: _saving || v.isDefault
                      ? null
                      : () => _set(const StudyPreferences()),
                  child: const Text('Reset to the usual rules'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.hint});
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: const TextStyle(color: planovaMuted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

/// One row of minute options. Options that would clash with another
/// preference are disabled, so an invalid combination cannot be picked.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.keyPrefix,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.enabled,
    this.label = formatDuration,
  });
  final String keyPrefix;
  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool Function(int)? enabled;
  final String Function(int) label;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final m in values)
        ChoiceChip(
          key: ValueKey('$keyPrefix-$m'),
          label: Text(label(m)),
          selected: m == selected,
          onSelected: enabled == null || enabled!(m) || m == selected
              ? (_) => onSelected(m)
              : null,
        ),
    ],
  );
}
