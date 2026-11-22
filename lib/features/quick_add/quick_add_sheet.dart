import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/time/app_clock.dart';
import '../../core/time/date_time_helpers.dart';
import '../../data/repositories/availability_repository.dart';
import '../../data/repositories/study_plan_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../models/study_session.dart';
import '../availability/screens/time_block_form.dart';
import '../courses/start_proforma_import.dart';
import '../planner/widgets/record_session_sheet.dart';
import '../tasks/screens/task_form_screen.dart';

enum _QuickAction { task, session, commitment, proforma }

/// The centre "+" in the tab bar: the same short list of things to add from
/// any tab, most used first. Planning itself stays on the Plan tab.
Future<void> showQuickAddSheet(
  BuildContext context, {
  required TaskRepository tasks,
  required AvailabilityRepository availability,
  required AppClock clock,
  StudyPlanRepository? plans,
}) async {
  final action = await showModalBottomSheet<_QuickAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Add',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          _option(
            context,
            _QuickAction.task,
            Icons.assignment_outlined,
            'Task or assessment',
            'An assignment, quiz, project or exam',
          ),
          _option(
            context,
            _QuickAction.session,
            Icons.check_circle_outline_rounded,
            'Record a study session',
            plans == null
                ? 'Not available in the demo'
                : 'Say how a planned session went',
            enabled: plans != null,
          ),
          _option(
            context,
            _QuickAction.commitment,
            Icons.event_busy_outlined,
            'Class or commitment',
            'Something fixed every week, like a lab or work',
          ),
          _option(
            context,
            _QuickAction.proforma,
            Icons.upload_file_outlined,
            'Import a proforma',
            'Add a course and its assessments from the PDF',
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  switch (action) {
    case _QuickAction.task:
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TaskFormScreen(repository: tasks, clock: clock),
        ),
      );
      if (saved == true) {
        messenger.showSnackBar(const SnackBar(content: Text('Task added.')));
      }
    case _QuickAction.session:
      await _pickSessionToRecord(context, plans!, clock);
    case _QuickAction.commitment:
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => TimeBlockForm.commitment(availability),
        ),
      );
    case _QuickAction.proforma:
      await startProformaImport(context, tasks, clock);
  }
}

Widget _option(
  BuildContext context,
  _QuickAction action,
  IconData icon,
  String title,
  String subtitle, {
  bool enabled = true,
}) => ListTile(
  key: ValueKey('quick-add-${action.name}'),
  enabled: enabled,
  leading: Icon(icon, color: enabled ? planovaOrange : null),
  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
  subtitle: Text(subtitle),
  minVerticalPadding: 12,
  onTap: () => Navigator.pop(context, action),
);

/// Sessions that have started and are not recorded yet, newest first.
List<StudySession> sessionsToRecord(StudyPlanRepository plans, DateTime now) =>
    plans.savedSessions.where((s) {
      if (s.isRecorded || s.startsAt.isAfter(now)) return false;
      final task = plans.tasks.taskById(s.taskId ?? '');
      return task != null && !task.isCompleted;
    }).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));

Future<void> _pickSessionToRecord(
  BuildContext context,
  StudyPlanRepository plans,
  AppClock clock,
) async {
  final candidates = sessionsToRecord(plans, clock.now());
  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          plans.hasPlan
              ? 'Nothing to record yet. Sessions appear here once they start.'
              : 'Create a plan on the Plan tab first.',
        ),
      ),
    );
    return;
  }
  final session = candidates.length == 1
      ? candidates.single
      : await showModalBottomSheet<StudySession>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      'Which session?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final s in candidates)
                    ListTile(
                      key: ValueKey('record-pick-${s.id}'),
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(s.title),
                      subtitle: Text(
                        '${weekdays[s.startsAt.weekday - 1]} '
                        '${s.startsAt.day} ${months[s.startsAt.month - 1]} · '
                        '${formatClock(s.startsAt.hour * 60 + s.startsAt.minute)} · '
                        '${formatDuration(s.minutes)}',
                      ),
                      onTap: () => Navigator.pop(context, s),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
  if (session == null || !context.mounted) return;
  await showRecordSessionSheet(context, plans: plans, session: session);
}
