import 'package:flutter/material.dart';

import '../../../models/proforma.dart';
import '../widgets/proforma_source_evidence.dart';

class WeeklyLearningEntryForm extends StatefulWidget {
  const WeeklyLearningEntryForm({super.key, required this.row});
  final WeeklyLearningDraft row;
  @override
  State<WeeklyLearningEntryForm> createState() =>
      _WeeklyLearningEntryFormState();
}

class _WeeklyLearningEntryFormState extends State<WeeklyLearningEntryForm> {
  final _form = GlobalKey<FormState>();
  late final _start = TextEditingController(text: '${widget.row.weekStart}');
  late final _end = TextEditingController(text: '${widget.row.weekEnd}');
  late final _topic = TextEditingController(text: widget.row.topic);
  late final _hours = [
    for (final value in [
      widget.row.guidedNf2fHours,
      widget.row.independentNf2fHours,
      ...widget.row.onlineHours.map((v) => v ?? 0.0),
      widget.row.totalSltHours,
    ])
      TextEditingController(text: value?.toString() ?? ''),
  ];
  @override
  void dispose() {
    for (final c in [_start, _end, _topic, ..._hours]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _week(String? text) {
    final value = int.tryParse(text?.trim() ?? '');
    return value == null || value < 1 || value > 30
        ? 'Enter a week from 1 to 30.'
        : null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    double? hour(int index) => double.tryParse(_hours[index].text.trim());
    Navigator.pop(
      context,
      WeeklyLearningDraft(
        weekStart: int.parse(_start.text.trim()),
        weekEnd: int.parse(_end.text.trim()),
        topic: _topic.text.trim(),
        guidedNf2fHours: hour(0),
        independentNf2fHours: hour(1),
        onlineHours: List.unmodifiable([for (var i = 2; i < 6; i++) hour(i)]),
        totalSltHours: hour(6),
        source: widget.row.source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit weekly entry')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Correct the week label, topic and planned hours using your proforma. Unknown NF2F or SLT values can stay blank.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('weekly-start'),
            controller: _start,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Start week'),
            validator: _week,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('weekly-end'),
            controller: _end,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'End week'),
            validator: (text) {
              final error = _week(text);
              if (error != null) return error;
              return int.parse(text!.trim()) <
                      (int.tryParse(_start.text.trim()) ?? 1)
                  ? 'End week must be on or after start week.'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('weekly-topic'),
            controller: _topic,
            minLines: 3,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Topic and subtopics'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Enter a topic.' : null,
          ),
          const SizedBox(height: 16),
          const Text(
            'Use hours, for example 0.5 for 30 minutes. These are planned course hours, not remaining task effort.',
          ),
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextFormField(
                key: ValueKey('weekly-hours-$i'),
                controller: _hours[i],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: [
                    'Guided NF2F hours',
                    'Independent NF2F hours',
                    'Online material · guided hours',
                    'Online material · non-guided hours',
                    'Online activities · guided hours',
                    'Online activities · non-guided hours',
                    'Total SLT hours',
                  ][i],
                  helperText: i >= 2 && i < 6
                      ? 'Blank source Online cells start at 0.'
                      : 'Leave blank if unknown.',
                ),
                validator: (text) {
                  if ((text ?? '').trim().isEmpty) {
                    return i >= 2 && i < 6 ? 'Enter hours or 0.' : null;
                  }
                  final value = double.tryParse(text!.trim());
                  return value == null || !value.isFinite || value < 0
                      ? 'Enter a non-negative number of hours.'
                      : null;
                },
              ),
            ),
          const SizedBox(height: 20),
          ProformaSourceEvidence(source: widget.row.source),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FilledButton(onPressed: _save, child: const Text('Use changes')),
      ),
    ),
  );
}
