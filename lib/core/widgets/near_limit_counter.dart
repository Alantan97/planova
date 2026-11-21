import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Character counter for `buildCounter`: hidden until the text is within 20%
/// of [maxLength], so short fields are not cluttered with "0/100".
Widget? nearLimitCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) {
  if (maxLength == null || currentLength < (maxLength * 0.8).floor()) {
    return null;
  }
  return Text(
    '$currentLength/$maxLength',
    style: TextStyle(
      color: currentLength >= maxLength
          ? Theme.of(context).colorScheme.error
          : planovaMuted,
      fontSize: 12,
    ),
  );
}
