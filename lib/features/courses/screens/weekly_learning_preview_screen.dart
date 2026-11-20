import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/errors/academic_save_error.dart';
import '../../../core/widgets/study_components.dart';
import '../../../models/proforma.dart';
import '../widgets/proforma_source_evidence.dart';
import 'weekly_learning_entry_form.dart';

class WeeklyLearningPreviewScreen extends StatefulWidget {
  const WeeklyLearningPreviewScreen({
    super.key,
    required this.rows,
    this.onSave,
    this.saveLabel = 'Save changes',
    this.description,
    this.lockedIdentities = const {},
  });
  final List<WeeklyLearningDraft> rows;
  final Future<void> Function(List<WeeklyLearningDraft>)? onSave;
  final String saveLabel;
  final String? description;
  final Set<String> lockedIdentities;
  @override
  State<WeeklyLearningPreviewScreen> createState() =>
      _WeeklyLearningPreviewScreenState();
}

class _WeeklyLearningPreviewScreenState
    extends State<WeeklyLearningPreviewScreen> {
  late final List<WeeklyLearningDraft> rows = List.of(widget.rows);
  bool _saving = false;
  String? _error;

  Future<void> _edit(int index) async {
    final value = await Navigator.push<WeeklyLearningDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklyLearningEntryForm(row: rows[index]),
      ),
    );
    if (value != null && mounted) setState(() => rows[index] = value);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave!(List.unmodifiable(rows));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is StateError || error is FormatException
              ? academicSaveError(error)
              : 'Could not save weekly learning. Your changes are still here; try again.';
        });
      }
    }
  }

  String _hours(double? value) => value == null
      ? 'Unknown'
      : '${value == value.roundToDouble() ? value.toInt() : value} h';

  Widget _value(String label, double? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: Text(label)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _hours(value),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weekly learning')),
    body: ListView(
      key: const PageStorageKey('weekly-preview-scroll'),
      padding: const EdgeInsets.all(24),
      children: [
        FeaturedPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.menu_book_outlined, color: planovaOrange),
              const SizedBox(height: 12),
              Text(
                '${rows.length} learning entries',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Course workload reference. These are not your remaining task hours.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.description ?? 'Preview only: weekly entries are not saved with this import yet.',
          style: const TextStyle(color: planovaMuted, height: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Compare the entries with your PDF. Blank Online cells mean zero under the confirmed UPSI convention; blank NF2F cells remain unknown.',
          style: TextStyle(color: planovaMuted, height: 1.5),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              key: PageStorageKey(
                'weekly-${row.source.fingerprint}-${row.source.rowId}',
              ),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: planovaBorder),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: planovaBorder),
              ),
              title: Text(
                row.weekLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                row.topic,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              children: [
                if (widget.onSave != null &&
                    !widget.lockedIdentities.contains(
                      '${row.source.fingerprint}/${row.source.rowId}',
                    ))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _edit(rows.indexOf(row)),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit entry'),
                    ),
                  ),
                if (widget.lockedIdentities.contains(
                  '${row.source.fingerprint}/${row.source.rowId}',
                ))
                  const Text(
                    'Already saved. Edit this entry from Courses & semesters.',
                  ),
                SelectableText(
                  row.topic,
                  key: PageStorageKey(
                    'weekly-topic-${row.source.fingerprint}-${row.source.rowId}-${row.source.page}',
                  ),
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 16),
                if (row.weekStart != row.weekEnd)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Hours cover this entire week range. Do not multiply them by the number of weeks.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                _value('Guided learning · NF2F', row.guidedNf2fHours),
                _value('Independent learning · NF2F', row.independentNf2fHours),
                const Divider(height: 24),
                for (var i = 0; i < 4; i++)
                  _value(
                    [
                      'Online material · guided',
                      'Online material · non-guided',
                      'Online activities · guided',
                      'Online activities · non-guided',
                    ][i],
                    row.onlineHours[i] ?? 0,
                  ),
                if (row.onlineHours.contains(null))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Blank source Online cells are shown as 0 h.',
                      style: TextStyle(color: planovaMuted),
                    ),
                  ),
                const Divider(height: 24),
                _value(
                  'Total SLT · includes all components',
                  row.totalSltHours,
                ),
                const Text(
                  'SLT also includes face-to-face learning. Do not add it to the hours above.',
                  style: TextStyle(color: planovaMuted),
                ),
                ProformaSourceEvidence(source: row.source),
              ],
            ),
          ),
      ],
    ),
    bottomNavigationBar: widget.onSave == null
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : widget.saveLabel),
              ),
            ),
          ),
  );
}
