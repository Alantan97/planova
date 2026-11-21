import 'package:flutter/material.dart';

/// "Here is what is missing" with a button to the step that fixes it, so an
/// empty step is never a dead end.
class FixPanel extends StatelessWidget {
  const FixPanel({
    super.key,
    required this.message,
    required this.action,
    required this.buttonKey,
    required this.onPressed,
  });
  final String message;
  final String action;
  final String buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4EC),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: ValueKey(buttonKey),
          onPressed: onPressed,
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(action),
        ),
      ],
    ),
  );
}
