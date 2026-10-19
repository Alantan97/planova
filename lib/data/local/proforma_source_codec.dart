import '../../models/proforma.dart';

class ProformaSourceCodec {
  static Map<String, Object?>? encode(ProformaSource? source) => source == null
      ? null
      : {
          'fingerprint': source.fingerprint,
          'fileName': source.fileName,
          'page': source.page,
          'rowId': source.rowId,
          'excerpt': source.excerpt,
          'assessmentWeight': source.assessmentWeight,
        };
  static ProformaSource? decode(Object? saved) {
    if (saved == null) return null;
    if (saved is! Map) throw const FormatException('Invalid proforma source.');
    String text(String key) {
      final value = saved[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid proforma evidence.');
      }
      return value;
    }

    final hash = text('fingerprint');
    final page = saved['page'];
    final weight = saved['assessmentWeight'];
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        page is! int ||
        page < 1 ||
        (weight != null &&
            (weight is! num ||
                !weight.isFinite ||
                weight < 0 ||
                weight > 100))) {
      throw const FormatException('Invalid proforma evidence.');
    }
    return ProformaSource(
      fingerprint: hash,
      fileName: text('fileName'),
      page: page,
      rowId: text('rowId'),
      excerpt: text('excerpt'),
      assessmentWeight: (weight as num?)?.toDouble(),
    );
  }
}
