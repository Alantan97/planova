import 'package:flutter/material.dart';

import '../../models/study_session.dart';
import '../theme/app_theme.dart';
import '../time/date_time_helpers.dart';
import 'study_components.dart';

IconData sessionIcon(StudySession session) {
  if (session.commitment) return Icons.school_outlined;
  return switch (session.subject) {
    'Computer Networks' => Icons.hub_outlined,
    'Mathematics' => Icons.functions_rounded,
    'Data Structures' => Icons.account_tree_outlined,
    'Database Systems' => Icons.storage_rounded,
    _ => Icons.edit_note_rounded,
  };
}

void showSessionDetails(BuildContext context, StudySession session) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Eyebrow('SAMPLE SESSION'),
            const SizedBox(height: 12),
            Text(
              session.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(session.subject, style: const TextStyle(color: planovaMuted)),
            const SizedBox(height: 24),
            Panel(
              child: Row(
                children: [
                  Icon(sessionIcon(session), color: planovaOrange),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${session.time} · ${session.minutes} min',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(session.commitment ? 'Fixed' : 'Study'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              session.commitment
                  ? 'A fixed commitment in this sample week.'
                  : session.status == SessionStatus.completed
                  ? 'Completed in the sample data. Opening this preview does not record additional study time.'
                  : 'A sample study block. No study time or task completion is recorded by opening this preview.',
              style: const TextStyle(color: planovaMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close preview'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NextSessionCard extends StatelessWidget {
  const NextSessionCard(this.session, {super.key, this.onOpen});
  final StudySession session;

  /// Set for real plan sessions; sample sessions open a read-only preview.
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) => FeaturedPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 20, color: planovaOrange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                onOpen == null
                    ? 'Sample study session'
                    : 'Next study session · rule-based plan',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          session.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          session.subject,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 18, color: planovaOrange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${session.time} · ${session.minutes} min',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpen ?? () => showSessionDetails(context, session),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(onOpen == null ? 'View session' : 'Open session'),
          ),
        ),
      ],
    ),
  );
}

class SessionRow extends StatelessWidget {
  const SessionRow(this.session, {super.key, this.onTap});
  final StudySession session;

  /// Set for real plan sessions (opens the record sheet). Without it the row
  /// is a sample or a fixed commitment and opens the read-only preview.
  final VoidCallback? onTap;

  String get _status {
    if (session.commitment) return 'Fixed commitment';
    if (onTap == null) {
      return session.status == SessionStatus.completed
          ? 'Completed · Sample'
          : 'Study session';
    }
    return switch (session.status) {
      SessionStatus.completed =>
        'Done · ${formatDuration(session.studiedMinutes)} recorded',
      SessionStatus.partial =>
        'Partly done · ${formatDuration(session.studiedMinutes)} recorded',
      SessionStatus.missed => 'Missed',
      SessionStatus.planned => 'Study session · tap to record',
    };
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              session.time,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Expanded(
          child: Material(
            color: session.commitment ? const Color(0xFFF5F5F5) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap ?? () => showSessionDetails(context, session),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          sessionIcon(session),
                          size: 16,
                          color: planovaMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            session.subject,
                            style: const TextStyle(
                              fontSize: 11,
                              color: planovaMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${session.minutes} min · $_status',
                      style: const TextStyle(fontSize: 12, color: planovaMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
