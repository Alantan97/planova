import '../../models/weekly_availability.dart';

/// Converts availability to and from plain maps for Sembast.
///
/// Decoding re-runs the model's validation, so corrupt saved data raises a
/// [FormatException] instead of silently producing an impossible week.
abstract final class AvailabilityCodec {
  static const schemaVersion = 1;

  static Map<String, Object?> encode(WeeklyAvailability value) => {
    'schemaVersion': schemaVersion,
    'windows': [
      for (final window in value.windows)
        {'id': window.id, ..._encodeRange(window.range)},
    ],
    'commitments': [
      for (final commitment in value.commitments)
        {
          'id': commitment.id,
          'title': commitment.title,
          'category': commitment.category.name,
          ..._encodeRange(commitment.range),
        },
    ],
  };

  static WeeklyAvailability decode(Map<String, Object?> map) {
    if (map['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported availability data version.');
    }
    return WeeklyAvailability(
      windows: [
        for (final item in _list(map['windows']))
          StudyWindow(id: _string(item, 'id'), range: _decodeRange(item)),
      ],
      commitments: [
        for (final item in _list(map['commitments']))
          RecurringCommitment(
            id: _string(item, 'id'),
            title: _string(item, 'title'),
            category: CommitmentCategory.values.firstWhere(
              (category) => category.name == item['category'],
              orElse: () =>
                  throw const FormatException('Unknown commitment category.'),
            ),
            range: _decodeRange(item),
          ),
      ],
    );
  }

  static Map<String, Object?> _encodeRange(WeeklyTimeRange range) => {
    'weekdays': range.weekdays,
    'startMinute': range.startMinute,
    'endMinute': range.endMinute,
  };

  static WeeklyTimeRange _decodeRange(Map<String, Object?> item) {
    final days = item['weekdays'];
    final start = item['startMinute'];
    final end = item['endMinute'];
    if (days is! List || days.any((d) => d is! int)) {
      throw const FormatException('Saved availability days are invalid.');
    }
    if (start is! int || end is! int) {
      throw const FormatException('Saved availability time is invalid.');
    }
    return WeeklyTimeRange(
      weekdays: days.cast<int>(),
      startMinute: start,
      endMinute: end,
    );
  }

  static List<Map<String, Object?>> _list(Object? value) {
    if (value is! List || value.any((item) => item is! Map)) {
      throw const FormatException('Saved availability list is invalid.');
    }
    return [for (final item in value) Map<String, Object?>.from(item as Map)];
  }

  static String _string(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Saved availability $key is missing.');
    }
    return value;
  }
}
