import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w700,
      color: planovaMuted,
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 4,
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      ?trailing,
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border.all(color: planovaBorder),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

/// A single focal panel for a page; ordinary cards keep the light Panel style.
class FeaturedPanel extends StatelessWidget {
  const FeaturedPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: planovaInk,
      borderRadius: BorderRadius.circular(20),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: IconTheme(
        data: const IconThemeData(color: planovaOrange),
        child: child,
      ),
    ),
  );
}

class DemoTag extends StatelessWidget {
  const DemoTag(this.text, {super.key});
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

class DateTile extends StatelessWidget {
  const DateTile({super.key, required this.day, required this.month});
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
            color: planovaActionOrange,
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

class DemoNote extends StatelessWidget {
  const DemoNote({super.key});
  @override
  Widget build(BuildContext context) => const Text(
    'Study sessions and study hours are samples. Saved tasks are separate; no AI schedule has been generated.',
    style: TextStyle(fontSize: 12, color: planovaMuted, height: 1.5),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final titleWidget = Text(
        title,
        style: const TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
      );
      final stackAction =
          constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (action != null && !stackAction)
            Row(
              children: [
                Expanded(child: titleWidget),
                const SizedBox(width: 12),
                action!,
              ],
            )
          else
            titleWidget,
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                color: planovaMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (action != null && stackAction) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      );
    },
  );
}
