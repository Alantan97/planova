import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/study_components.dart';

/// "STEP 2 OF 3 · COURSES" with a segmented progress bar.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.label,
    required this.current,
    required this.total,
  });
  final String label;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= current ? planovaActionOrange : planovaBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
