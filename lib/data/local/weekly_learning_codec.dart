import '../../models/proforma.dart';
import 'proforma_source_codec.dart';

class WeeklyLearningCodec {
  static Map<String, Object?> _encode(WeeklyLearningDraft row) => {
    'weekStart': row.weekStart,
    'weekEnd': row.weekEnd,
    'topic': row.topic,
    'guidedNf2fHours': row.guidedNf2fHours,
    'independentNf2fHours': row.independentNf2fHours,
    'onlineHours': row.onlineHours,
    'totalSltHours': row.totalSltHours,
    'source': ProformaSourceCodec.encode(row.source),
  };

  static List<Map<String, Object?>> encode(
    List<ReviewedWeeklyLearning> rows,
  ) => [
    for (final row in rows)
      {'printed': _encode(row.printed), 'confirmed': _encode(row.confirmed)},
  ];

  static WeeklyLearningDraft _decode(Object? saved) {
    if (saved is! Map) {
      throw const FormatException('Invalid weekly learning record.');
    }
    final start = saved['weekStart'];
    final end = saved['weekEnd'];
    final topic = saved['topic'];
    final online = saved['onlineHours'];
    final source = ProformaSourceCodec.decode(saved['source']);
    if (start is! int ||
        end is! int ||
        start < 1 ||
        end < start ||
        end > 30 ||
        topic is! String ||
        topic.trim().isEmpty ||
        online is! List ||
        online.length != 4 ||
        source == null) {
      throw const FormatException('Invalid weekly learning fields.');
    }
    double? hours(Object? value) {
      if (value == null) return null;
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException('Invalid weekly learning hours.');
      }
      return value.toDouble();
    }

    return WeeklyLearningDraft(
      weekStart: start,
      weekEnd: end,
      topic: topic,
      guidedNf2fHours: hours(saved['guidedNf2fHours']),
      independentNf2fHours: hours(saved['independentNf2fHours']),
      onlineHours: List.unmodifiable(online.map(hours)),
      totalSltHours: hours(saved['totalSltHours']),
      source: source,
    );
  }

  static List<ReviewedWeeklyLearning> decode(Object? saved) {
    if (saved == null) return const [];
    if (saved is! List) {
      throw const FormatException('Invalid weekly learning list.');
    }
    return List.unmodifiable(
      saved.map((row) {
        if (row is! Map) {
          throw const FormatException('Invalid reviewed weekly record.');
        }
        return ReviewedWeeklyLearning(
          printed: _decode(row['printed']),
          confirmed: _decode(row['confirmed']),
        );
      }),
    );
  }
}
