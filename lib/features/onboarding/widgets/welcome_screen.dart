import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// First screen of the journey: what Planova is, and how to continue.
/// "Continue with Google" is a placeholder until real sign-in is connected.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.busy,
    required this.onGoogle,
    required this.onGuest,
  });
  final bool busy;
  final VoidCallback onGoogle;
  final VoidCallback onGuest;

  // Scrolls on small screens or with large text; when there is room the
  // spacers still spread the content over the screen.
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: IntrinsicHeight(child: _content()),
          ),
        ),
      ),
    ),
  );

  Widget _content() => Center(
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
              onPressed: busy ? null : onGoogle,
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('onboarding-guest'),
              onPressed: busy ? null : onGuest,
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
}
