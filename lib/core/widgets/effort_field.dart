import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Upper limit for one task's effort: one week (10080 minutes).
const maxEffortMinutes = 7 * 24 * 60;

/// Effort entered as hours + minutes, with quick choices.
///
/// [controller] always holds the total in minutes (e.g. "90", or "" when both
/// boxes are empty), so storage and validation keep working in minutes while
/// students think in hours.
class EffortField extends StatefulWidget {
  const EffortField({
    super.key,
    required this.controller,
    required this.fieldKey,
    required this.label,
    required this.validate,
    this.helper,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;

  /// Prefix for the sub-field keys: '$fieldKey-hours', '$fieldKey-minutes'.
  final String fieldKey;
  final String label;
  final String? helper;
  final bool enabled;

  /// Receives the total minutes (null when nothing valid is entered).
  final String? Function(int? totalMinutes) validate;
  final FocusNode? focusNode;
  final VoidCallback? onChanged;

  @override
  State<EffortField> createState() => _EffortFieldState();
}

class _EffortFieldState extends State<EffortField> {
  late final TextEditingController _hours;
  late final TextEditingController _minutes;

  @override
  void initState() {
    super.initState();
    final total = int.tryParse(widget.controller.text);
    _hours = TextEditingController(
      text: total == null || total < 60 ? '' : '${total ~/ 60}',
    );
    _minutes = TextEditingController(
      text: total == null || total % 60 == 0 && total >= 60
          ? ''
          : '${total % 60}',
    );
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _sync(FormFieldState<int> field) {
    final hours = int.tryParse(_hours.text);
    final minutes = int.tryParse(_minutes.text);
    widget.controller.text = hours == null && minutes == null
        ? ''
        : '${(hours ?? 0) * 60 + (minutes ?? 0)}';
    field.didChange(int.tryParse(widget.controller.text));
    widget.onChanged?.call();
  }

  void _choose(FormFieldState<int> field, int total) {
    _hours.text = total >= 60 ? '${total ~/ 60}' : '';
    _minutes.text = total % 60 == 0 ? '' : '${total % 60}';
    _sync(field);
  }

  @override
  Widget build(BuildContext context) => FormField<int>(
    validator: (_) => widget.validate(int.tryParse(widget.controller.text)),
    builder: (field) {
      final error = field.errorText;
      InputDecoration box(String label) => InputDecoration(
        labelText: label,
        error: error == null ? null : const SizedBox.shrink(),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('${widget.fieldKey}-hours'),
                  controller: _hours,
                  focusNode: widget.focusNode,
                  enabled: widget.enabled,
                  decoration: box('Hours'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onChanged: (_) => _sync(field),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: ValueKey('${widget.fieldKey}-minutes'),
                  controller: _minutes,
                  enabled: widget.enabled,
                  decoration: box('Minutes'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (_) => _sync(field),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, total) in const [
                ('30 min', 30),
                ('1 h', 60),
                ('2 h', 120),
                ('3 h', 180),
                ('5 h', 300),
              ])
                ActionChip(
                  key: ValueKey('${widget.fieldKey}-quick-$total'),
                  label: Text(label),
                  onPressed: widget.enabled
                      ? () => setState(() => _choose(field, total))
                      : null,
                ),
            ],
          ),
          if (error != null || widget.helper != null) ...[
            const SizedBox(height: 8),
            Text(
              error ?? widget.helper!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: error != null
                    ? Theme.of(context).colorScheme.error
                    : planovaMuted,
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Shared rule for task effort, phrased in hours.
String? validateEffort(int? total, {int recorded = 0}) {
  if (total == null || total < 1 || total > maxEffortMinutes) {
    return 'Enter a time from 1 minute to 168 hours.';
  }
  if (total < recorded) {
    return 'Must be at least the ${_hm(recorded)} already recorded.';
  }
  return null;
}

String _hm(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}
