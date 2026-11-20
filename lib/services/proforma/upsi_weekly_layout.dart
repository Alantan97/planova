import '../../models/proforma.dart';

/// Recognizes the inspected UPSI weekly grid using header positions and PDF order.
/// Missing conventional values stay null; Online interpretation belongs to review.
class UpsiWeeklyLayout {
  List<WeeklyLearningDraft> read(
    List<List<ProformaTextWord>> pages, {
    required String fingerprint,
    required String fileName,
  }) {
    final result = <WeeklyLearningDraft>[];
    List<double>? centers;
    double? weekLeft, weekRight, topicRight;
    final labelPattern = RegExp(r'^\d{1,2}(?:[-–]\d{1,2})?$');
    for (var p = 0; p < pages.length; p++) {
      final words = pages[p];
      var begin = 0;
      final headerIndex = words.indexWhere((w) => w.text == 'Week');
      if (headerIndex >= 0) {
        final week = words[headerIndex];
        weekLeft = week.left - 12;
        weekRight = week.right + 8;
        final headerEnd = words.indexWhere(
          (w) =>
              w.left >= weekLeft! &&
              w.right <= weekRight! &&
              labelPattern.hasMatch(w.text),
          headerIndex + 1,
        );
        final header = words.sublist(
          headerIndex,
          headerEnd < 0 ? words.length : headerEnd,
        );
        if ([
          'Conventional',
          'Online',
          'Material',
          'Activities',
        ].any((label) => !header.any((word) => word.text == label))) {
          centers = null;
          continue;
        }
        final f2f = [
          for (final letter in ['L', 'T', 'P', 'O'])
            header.where((w) => w.text == letter).toList(),
        ];
        final nf2f = header.where((w) => w.text == '(NF2F)').toList()
          ..sort((a, b) => a.left.compareTo(b.left));
        final clo = header
            .where((w) => RegExp(r'^CLO\d$').hasMatch(w.text))
            .toList();
        final slt = header.where((w) => w.text == 'SLT').toList();
        if (f2f.any((column) => column.length != 1) ||
            nf2f.length != 2 ||
            clo.isEmpty ||
            slt.length != 1) {
          centers = null;
          continue;
        }
        final online =
            header
                .where((w) => w.text == 'Guided' && w.left > nf2f.last.right)
                .toList()
              ..sort((a, b) => a.left.compareTo(b.left));
        if (online.length != 4) {
          centers = null;
          continue;
        }
        double center(ProformaTextWord w) => (w.left + w.right) / 2;
        centers = [
          for (final column in f2f) center(column.single),
          for (final w in nf2f) center(w),
          for (final w in online) center(w),
          center(slt.single),
        ];
        if (List.generate(
          centers.length - 1,
          (i) => centers![i] < centers[i + 1],
        ).any((ordered) => !ordered)) {
          centers = null;
          continue;
        }
        topicRight = clo.map((w) => w.left).reduce((a, b) => a < b ? a : b) - 2;
        begin = headerEnd < 0 ? words.length : headerEnd;
      }
      if (centers == null ||
          weekLeft == null ||
          weekRight == null ||
          topicRight == null) {
        continue;
      }
      var stop = -1;
      for (var i = begin; i < words.length; i++) {
        if (words[i].text == 'TOTAL' ||
            (i + 1 < words.length &&
                (words[i].text == 'Continuous' || words[i].text == 'Final') &&
                words[i + 1].text == 'Assessment' &&
                words[i].left > weekRight + 20)) {
          stop = i;
          break;
        }
      }
      final end = stop < 0 ? words.length : stop;
      final starts = <int>[];
      for (var i = begin; i < end; i++) {
        final w = words[i];
        if (w.left >= weekLeft &&
            w.right <= weekRight &&
            labelPattern.hasMatch(w.text)) {
          if (i > begin &&
              words[i - 1].left >= weekLeft &&
              words[i - 1].right <= weekRight &&
              (words[i - 1].centerY - w.centerY).abs() < 2.5) {
            continue; // A later token in a spaced week range such as 3 - 4.
          }
          starts.add(i);
        }
      }
      for (var r = 0; r < starts.length; r++) {
        final block = words.sublist(
          starts[r],
          r + 1 < starts.length ? starts[r + 1] : end,
        );
        final label = block
            .where((w) => w.right <= weekRight!)
            .map((w) => w.text)
            .join('');
        final range = RegExp(r'^(\d{1,2})(?:[-–](\d{1,2}))?$')
            .firstMatch(label);
        if (range == null) continue;
        final start = int.parse(range[1]!);
        final finish = int.parse(range[2] ?? range[1]!);
        if (start < 1 || finish < start || finish > 30) continue;
        final firstEdge = centers[0] - (centers[1] - centers[0]) / 2;
        final numeric = List<List<ProformaTextWord>>.generate(11, (_) => []);
        final topicWords = <ProformaTextWord>[];
        for (final w in block.skip(1)) {
          if (w.left > weekRight - 10 &&
              w.right > weekRight &&
              w.right < topicRight + 2) {
            topicWords.add(w);
          }
          final x = (w.left + w.right) / 2;
          if (x < firstEdge) continue;
          for (var c = 0; c < centers.length; c++) {
            final right = c + 1 < centers.length
                ? (centers[c] + centers[c + 1]) / 2
                : centers[c] + (centers[c] - centers[c - 1]) / 2;
            if (x < right) {
              numeric[c].add(w);
              break;
            }
          }
        }
        double? value(int column) => numeric[column].isEmpty
            ? null
            : numeric[column].length == 1
            ? double.tryParse(numeric[column].single.text)
            : null;
        final topic = normalizeTopic(topicWords.map((w) => w.text).join(' '));
        if (topic.isEmpty ||
            numeric.any((cell) => cell.length > 1) ||
            numeric
                .expand((v) => v)
                .any((w) => double.tryParse(w.text) == null) ||
            numeric
                .expand((v) => v)
                .any(
                  (w) =>
                      double.parse(w.text) < 0 ||
                      !double.parse(w.text).isFinite,
                )) {
          continue;
        }
        result.add(
          WeeklyLearningDraft(
            weekStart: start,
            weekEnd: finish,
            topic: topic,
            guidedNf2fHours: value(4),
            independentNf2fHours: value(5),
            onlineHours: List.unmodifiable([
              for (var i = 6; i < 10; i++) value(i),
            ]),
            totalSltHours: value(10),
            source: ProformaSource(
              fingerprint: fingerprint,
              fileName: fileName,
              page: p + 1,
              rowId: 'weekly-${p + 1}-${r + 1}',
              excerpt: block.map((w) => w.text).join(' '),
            ),
          ),
        );
      }
      if (stop >= 0) centers = null;
    }
    return List.unmodifiable(result);
  }

  static String normalizeTopic(String text) {
    const ligatures = {'ﬀ': 'ff', 'ﬁ': 'fi', 'ﬂ': 'fl', 'ﬃ': 'ffi', 'ﬄ': 'ffl'};
    for (final entry in ligatures.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    text = text.replaceAllMapped(
      RegExp(r'[\uFF01-\uFF5E]'),
      (match) => String.fromCharCode(match[0]!.codeUnitAt(0) - 0xFEE0),
    );
    return text
        .replaceAll('\u200b', '')
        .replaceAll('\u0002', '-')
        .replaceAllMapped(
          RegExp(r'([A-Za-z])-\s+(?=[a-z])'),
          (match) => '${match[1]}-',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(RegExp(r'\s+([),.;:])'), (match) => match[1]!)
        .trim();
  }
}
