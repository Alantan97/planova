import '../../models/proforma.dart';

typedef LocatedAssessment = ({
  String section,
  String number,
  String title,
  double weight,
  int page,
  String excerpt,
});

/// Reads explicit percentages by position, without interpreting blank hour cells.
class UpsiAssessmentLayout {
  Iterable<LocatedAssessment> read(List<List<ProformaTextWord>> pages) sync* {
    String? section;
    double? weightLeft;
    double? weightRight;
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
        }
        if (line.startsWith('TOTAL') || line.startsWith('GRAND TOTAL')) {
          section = null;
          weightLeft = null;
          weightRight = null;
          continue;
        }
        if (section == null) continue;
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
        yield (
          section: section,
          number: words.first.text,
          title: title,
          weight: weight,
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
