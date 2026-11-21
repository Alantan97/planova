import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Heading and short explanation at the top of a step.
class StepIntro extends StatelessWidget {
  const StepIntro(this.title, this.body, {super.key});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(body, style: const TextStyle(color: planovaMuted, height: 1.5)),
      const SizedBox(height: 24),
    ],
  );
}
