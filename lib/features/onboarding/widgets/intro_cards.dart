import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Step 1: three short cards explaining the idea, swipe or tap Next.
class IntroCards extends StatefulWidget {
  const IntroCards({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<IntroCards> createState() => IntroCardsState();
}

class IntroCardsState extends State<IntroCards> {
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
                      LayoutBuilder(
                        builder: (context, box) => SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: box.maxHeight - 48,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4EC),
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 56,
                                    color: planovaActionOrange,
                                  ),
                                ),
                                const SizedBox(height: 32),
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
