import '../../models/proforma.dart';

typedef LocatedAssessment = ({
  String section,
  String number,
  String title,
  double weight,
  double? sltHours,
  int page,
  String excerpt,
});

/// Reads explicit percentages by position, without interpreting blank hour cells.
///
/// The total study hours (SLT column) are read the same way: only a single
/// number printed inside the SLT header's column counts. Anything else leaves
/// the hours unknown rather than guessing from neighbouring columns.
class UpsiAssessmentLayout {
  Iterable<LocatedAssessment> read(List<List<ProformaTextWord>> pages) sync* {
    String? section;
    double? weightLeft;
    double? weightRight;
    double? sltLeft;
    double? sltRight;
    final number = RegExp(r'^\d+(?:\.\d+)?$');
    for (var p = 0; p < pages.length; p++) {
      for (final words in _lines(pages[p])) {
        final line = words.map((word) => word.text).join(' ');
        if (line.contains('Continuous Assessment') ||
            line.contains('Final Assessment')) {
          section = line.contains('Continuous Assessment')
              ? 'continuous'
              : 'final';
          weightLeft = null;
          weightRight = null;
          sltLeft = null;
          sltRight = null;
        }
        if (line.startsWith('TOTAL') || line.startsWith('GRAND TOTAL')) {
          section = null;
          weightLeft = null;
          weightRight = null;
          sltLeft = null;
          sltRight = null;
          continue;
        }
        if (section == null) continue;
        final slt = words.indexWhere((w) => w.text == 'SLT');
        if (slt >= 0 && !RegExp(r'^\d+$').hasMatch(words.first.text)) {
          sltLeft = words[slt].left - 6;
          sltRight = words[slt].right + 6;
        }
        final header = words.indexWhere((w) => w.text == 'Percentage');
        if (header >= 0) {
          weightLeft = words[header].left - 3;
          weightRight = words[header].right + 3;
          if (header + 1 < words.length && words[header + 1].text == '(%)') {
            weightRight = words[header + 1].right + 3;
          }
          continue;
        }
        if (weightLeft == null || weightRight == null || words.length < 3) {
          continue;
        }
        if (!RegExp(r'^\d+$').hasMatch(words.first.text)) continue;
        final weights = words
            .where(
              (w) =>
                  w.left >= weightLeft! &&
                  w.right <= weightRight! &&
                  number.hasMatch(w.text),
            )
            .toList();
        if (weights.length != 1) continue;
        final weightWord = weights.single;
        final index = words.indexOf(weightWord);
        if (index <= 1) continue;
        final title = words.sublist(1, index).map((w) => w.text).join(' ');
        final weight = double.parse(weightWord.text);
        if (weight > 100 || !RegExp(r'[A-Za-z]').hasMatch(title)) continue;
        final hours = sltLeft == null || sltRight == null
            ? const <ProformaTextWord>[]
            : words
                  .where(
                    (w) =>
                        w != weightWord &&
                        w.left >= sltLeft! &&
                        w.right <= sltRight! &&
                        number.hasMatch(w.text),
                  )
                  .toList();
        yield (
          section: section,
          number: words.first.text,
          title: title,
          weight: weight,
          sltHours: hours.length == 1 ? double.parse(hours.single.text) : null,
          page: p + 1,
          excerpt: line,
        );
      }
    }
  }

  List<List<ProformaTextWord>> _lines(List<ProformaTextWord> words) {
    final sorted = [...words]..sort((a, b) => b.centerY.compareTo(a.centerY));
    final lines = <List<ProformaTextWord>>[];
    for (final word in sorted) {
      if (lines.isEmpty ||
          (lines.last.first.centerY - word.centerY).abs() > 2.5) {
        lines.add([word]);
      } else {
        lines.last.add(word);
      }
    }
    for (final line in lines) {
      line.sort((a, b) => a.left.compareTo(b.left));
    }
    return lines;
  }
}
