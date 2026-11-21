import 'package:flutter/material.dart';

import '../../../core/widgets/near_limit_counter.dart';
import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/date_time_helpers.dart';
import '../../../data/repositories/availability_repository.dart';
import '../../../models/weekly_availability.dart';

/// One form for both kinds of weekly time block, because they share days and
/// times. A commitment additionally has a name and a category.
class TimeBlockForm extends StatefulWidget {
  const TimeBlockForm.window(this.repository, [this.window, Key? key])
    : commitment = null,
      isCommitment = false,
      super(key: key);
  const TimeBlockForm.commitment(this.repository, [this.commitment, Key? key])
    : window = null,
      isCommitment = true,
      super(key: key);

  final AvailabilityRepository repository;
  final StudyWindow? window;
  final RecurringCommitment? commitment;
  final bool isCommitment;

  @override
  State<TimeBlockForm> createState() => _TimeBlockFormState();
}

class _TimeBlockFormState extends State<TimeBlockForm> {
  final _form = GlobalKey<FormState>();
  late final WeeklyTimeRange? _existing =
      widget.window?.range ?? widget.commitment?.range;
  late final _title = TextEditingController(text: widget.commitment?.title);
  late CommitmentCategory _category =
      widget.commitment?.category ?? CommitmentCategory.classes;
  late final Set<int> _days = {...?_existing?.weekdays};
  late int _start =
      _existing?.startMinute ?? (widget.isCommitment ? 8 * 60 : 20 * 60);
  late int _end =
      _existing?.endMinute ?? (widget.isCommitment ? 10 * 60 : 22 * 60);
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.window == null && widget.commitment == null;
  String get _noun => widget.isCommitment ? 'commitment' : 'study window';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60 % 24, minute: current % 60),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final minute = picked.hour * 60 + picked.minute;
      if (start) {
        _start = minute;
      } else {
        _end = minute;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final problem = WeeklyTimeRange.validate(
      weekdays: _days,
      startMinute: _start,
      endMinute: _end,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final range = WeeklyTimeRange(
        weekdays: _days,
        startMinute: _start,
        endMinute: _end,
      );
      final id =
          widget.window?.id ??
          widget.commitment?.id ??
          'local-${DateTime.now().microsecondsSinceEpoch}';
      if (widget.isCommitment) {
        await widget.repository.saveCommitment(
          RecurringCommitment(
            id: id,
            title: _title.text,
            category: _category,
            range: range,
          ),
        );
      } else {
        await widget.repository.saveWindow(StudyWindow(id: id, range: range));
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = academicSaveError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${_isNew ? 'Add' : 'Edit'} $_noun')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        widget.isCommitment
                            ? 'Something fixed in your week.'
                            : 'A time you usually study.',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.isCommitment
                            ? 'Study will never be planned over this time.'
                            : 'Choose the days and times you are normally free '
                                  'and willing to study.',
                        style: const TextStyle(
                          color: planovaMuted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (widget.isCommitment) ...[
                        TextFormField(
                          key: const ValueKey('commitment-title'),
                          controller: _title,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            hintText:
                                'e.g. DES3113 lecture, futsal, cafe shift',
                          ),
                          maxLength: 80,
                          buildCounter: nearLimitCounter,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter a name.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<CommitmentCategory>(
                          key: const ValueKey('commitment-category'),
                          initialValue: _category,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: [
                            for (final category in CommitmentCategory.values)
                              DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) => setState(
                                  () => _category = value ?? _category,
                                ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      const Text(
                        'Days',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var day = 1; day <= 7; day++)
                            FilterChip(
                              key: ValueKey('weekday-$day'),
                              label: Text(weekdays[day - 1]),
                              tooltip: fullWeekdays[day - 1],
                              selected: _days.contains(day),
                              onSelected: _saving
                                  ? null
                                  : (selected) => setState(() {
                                      selected
                                          ? _days.add(day)
                                          : _days.remove(day);
                                      _error = null;
                                    }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Time',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Start and end on the same day.',
                        style: TextStyle(color: planovaMuted, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        key: const ValueKey('start-time'),
                        onPressed: _saving ? null : () => _pickTime(true),
                        icon: const Icon(Icons.schedule),
                        label: Text('Starts: ${formatClock(_start)}'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const ValueKey('end-time'),
                        onPressed: _saving ? null : () => _pickTime(false),
                        icon: const Icon(Icons.schedule),
                        label: Text('Ends: ${formatClock(_end)}'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      FilledButton(
                        key: const ValueKey('save-time-block'),
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: planovaActionOrange,
                          foregroundColor: planovaOnOrange,
                        ),
                        child: Text(_saving ? 'Saving…' : 'Save $_noun'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
