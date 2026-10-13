import 'package:flutter/material.dart';

import 'theme.dart';

// Fixed synthetic fixtures for the UI preview; no ranking or GA output.
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _Session {
  const _Session(
    this.time,
    this.title,
    this.subject,
    this.minutes,
    this.icon, {
    this.commitment = false,
  });
  final String time;
  final String title;
  final String subject;
  final int minutes;
  final IconData icon;
  final bool commitment;
}

const _demoWeek = <int, List<_Session>>{
  0: [
    _Session(
      '09:00',
      'Review lecture notes',
      'Computer Networks',
      45,
      Icons.hub_outlined,
    ),
  ],
  1: [
    _Session(
      '15:00',
      'Practice integration',
      'Mathematics',
      60,
      Icons.functions_rounded,
    ),
  ],
  2: [
    _Session(
      '10:00',
      'Database lecture',
      'Lecture · Room B204',
      60,
      Icons.school_outlined,
      commitment: true,
    ),
    _Session(
      '14:00',
      'Get comfortable with graphs',
      'Data Structures',
      45,
      Icons.account_tree_outlined,
    ),
    _Session(
      '16:00',
      'Work through SQL joins',
      'Database Systems',
      60,
      Icons.storage_rounded,
    ),
  ],
  3: [
    _Session(
      '14:00',
      'Outline the project report',
      'Software Engineering',
      60,
      Icons.edit_note_rounded,
    ),
  ],
  4: [
    _Session(
      '09:00',
      'Practice integration',
      'Mathematics',
      45,
      Icons.functions_rounded,
    ),
  ],
};

class StudyHome extends StatefulWidget {
  const StudyHome({super.key});
  @override
  State<StudyHome> createState() => _StudyHomeState();
}

class _StudyHomeState extends State<StudyHome> {
  int _tab = 0;
  int _selectedDay = 2;
  int _weekOffset = 0;
  DateTime get _weekStart => DateTime(2026, 10, 12 + _weekOffset * 7);
  List<_Session> get _sessions =>
      _weekOffset == 0 ? _demoWeek[_selectedDay] ?? const [] : const [];

  void _showSession(_Session session) {
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
              const _Eyebrow('SAMPLE SESSION'),
              const SizedBox(height: 12),
              Text(
                session.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                session.subject,
                style: const TextStyle(color: planovaMuted),
              ),
              const SizedBox(height: 24),
              _Panel(
                child: Row(
                  children: [
                    Icon(session.icon, color: planovaOrange),
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
                session.commitment ? 'A fixed commitment in this sample week.' : 'A sample study block. No study time or task completion is recorded in this preview.',
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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            key: ValueKey(_tab),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                sliver: SliverToBoxAdapter(
                  child: _tab == 0 ? _today() : _plan(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE6E6E6))),
      ),
      child: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Plan',
          ),
        ],
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'planova full title black.png',
              width: 190,
              height: 40,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              semanticLabel: 'Planova logo',
            ),
          ),
        ),
        const SizedBox(width: 16),
        const _Tag('DEMO'),
      ],
    ),
  );

  Widget _today() {
    final sessions = _demoWeek[2]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('WEDNESDAY, 14 OCTOBER'),
        const SizedBox(height: 10),
        const Text(
          'Make room for progress.',
          style: TextStyle(
            fontSize: 38,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'A little focus. A step closer.',
          style: TextStyle(fontSize: 16, color: planovaMuted),
        ),
        const SizedBox(height: 24),
        _nextSession(sessions[1]),
        const SizedBox(height: 28),
        _SectionTitle(
          'Your day',
          trailing: TextButton.icon(
            onPressed: () => setState(() {
              _tab = 1;
              _weekOffset = 0;
              _selectedDay = 2;
            }),
            label: const Text('View plan'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            iconAlignment: IconAlignment.end,
          ),
        ),
        const Text(
          '2 study sessions · 1h 45m planned',
          style: TextStyle(color: planovaMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...sessions.map(_sessionRow),
        const SizedBox(height: 24),
        const _SectionTitle('Coming up'),
        const SizedBox(height: 16),
        const _Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateTile(day: '16', month: 'OCT'),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Database assignment',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Database Systems · Due Friday',
                      style: TextStyle(color: planovaMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Small steps add up'),
        const SizedBox(height: 16),
        const _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THIS WEEK · SAMPLE PROGRESS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: planovaMuted,
                ),
              ),
              SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '3h 30m',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' / 6h goal',
                      style: TextStyle(color: planovaMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                child: LinearProgressIndicator(
                  value: 3.5 / 6,
                  minHeight: 8,
                  color: planovaOrange,
                  backgroundColor: Color(0xFFE6E6E6),
                  semanticsLabel: 'Sample weekly progress',
                  semanticsValue: '58 percent',
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Every session counts.',
                style: TextStyle(color: planovaMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _DemoNote(),
      ],
    );
  }

  Widget _nextSession(_Session session) => Container(
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
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showSession(session),
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
  Widget _plan() {
    final start = _weekStart;
    final end = DateTime(start.year, start.month, start.day + 6);
    final date = DateTime(start.year, start.month, start.day + _selectedDay);
    final studyMinutes = _sessions
        .where((s) => !s.commitment)
        .fold<int>(0, (total, s) => total + s.minutes);
    final range = start.month == end.month
        ? '${start.day}–${end.day} ${_months[start.month - 1]} ${start.year}'
        : '${start.day} ${_months[start.month - 1]} – ${end.day} ${_months[end.month - 1]} ${end.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('A LITTLE STRUCTURE, MORE FOCUS'),
        const SizedBox(height: 10),
        const Text(
          'Your study plan.',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Space for studying. Space for life.',
          style: TextStyle(fontSize: 16, color: planovaMuted),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                range,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous week',
              onPressed: () => setState(() => _weekOffset--),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: () => setState(() => _weekOffset++),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 4,
              children: List.generate(7, (index) {
                final day = DateTime(
                  start.year,
                  start.month,
                  start.day + index,
                );
                final selected = _selectedDay == index;
                final hasSession =
                    _weekOffset == 0 && (_demoWeek[index]?.isNotEmpty ?? false);
                return SizedBox(
                  width: ((constraints.maxWidth - 24) / 7).clamp(48.0, 88.0),
                  child: Semantics(
                    selected: selected,
                    label:
                        '${_weekdays[index]} ${day.day} ${_months[day.month - 1]}',
                    child: Material(
                      color: selected ? planovaOrange : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: ValueKey('day-$index'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _selectedDay = index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Column(
                            children: [
                              Text(
                                _weekdays[index],
                                style: TextStyle(
                                  color: selected ? Colors.white : planovaInk,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: selected ? Colors.white : planovaInk,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasSession
                                      ? (selected ? Colors.white : planovaInk)
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _Panel(
          child: Row(
            children: [
              const Icon(Icons.auto_stories_outlined, color: planovaOrange),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$studyMinutes min of study',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fixed commitments shown separately',
                      style: TextStyle(color: planovaMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _SectionTitle(
          '${_weekdays[_selectedDay]}, ${date.day} ${_months[date.month - 1]}',
        ),
        const SizedBox(height: 18),
        if (_sessions.isEmpty)
          const _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wb_sunny_outlined, color: planovaOrange, size: 30),
                SizedBox(height: 14),
                Text(
                  'A little breathing room.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'No sessions in this sample day. Browse 12–18 October to explore the demo plan.',
                  style: TextStyle(color: planovaMuted, height: 1.5),
                ),
              ],
            ),
          )
        else
          ..._sessions.map(_sessionRow),
        const SizedBox(height: 24),
        const _DemoNote(),
      ],
    );
  }

  Widget _sessionRow(_Session session) => Padding(
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
              onTap: () => _showSession(session),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(session.icon, size: 16, color: planovaMuted),
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
                      '${session.minutes} min · ${session.commitment ? 'Fixed commitment' : 'Study session'}',
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

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w700,
      color: planovaMuted,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE6E6E6)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: planovaInk,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        letterSpacing: 1,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.day, required this.month});
  final String day;
  final String month;
  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          month,
          style: const TextStyle(
            fontSize: 10,
            color: planovaOrange,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          day,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _DemoNote extends StatelessWidget {
  const _DemoNote();
  @override
  Widget build(BuildContext context) => const Text(
    'Interface preview · Sample schedule and progress, not an AI-generated plan.',
    style: TextStyle(fontSize: 12, color: planovaMuted, height: 1.5),
  );
}
