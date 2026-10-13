import 'package:flutter/material.dart';

import '../../models/study_session.dart';
import '../theme/app_theme.dart';
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
                child: const Text('Back to schedule'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NextSessionCard extends StatelessWidget {
  const NextSessionCard(this.session, {super.key});
  final StudySession session;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE6E6E6)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: planovaInk,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 18, color: planovaOrange),
                    SizedBox(width: 6),
                    Text(
                      'UP NEXT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                session.subject,
                style: const TextStyle(
                  color: planovaMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                session.title,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 17,
                    color: planovaOrange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${session.time} · ${session.minutes} min',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: planovaInk,
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: planovaOrange,
              foregroundColor: planovaOnOrange,
            ),
            onPressed: () => showSessionDetails(context, session),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'View session',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class SessionRow extends StatelessWidget {
  const SessionRow(this.session, {super.key});
  final StudySession session;
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
              onTap: () => showSessionDetails(context, session),
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
                      '${session.minutes} min · ${session.commitment
                          ? 'Fixed commitment'
                          : session.status == SessionStatus.completed
                          ? 'Completed · Sample'
                          : 'Study session'}',
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
