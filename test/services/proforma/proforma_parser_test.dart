import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/models/proforma.dart';
import 'package:planova/services/proforma/proforma_import_service.dart';

import '../../support/proforma_fixtures.dart';

void main() {
  test('Layout reads an explicit percentage with blank hour cells', () async {
    final draft = await _layoutDraft([
      [],
      [
        ..._header(),
        ..._row('1', 660, weight: '30'),
        _word('TOTAL', 350, 630),
        ..._row('2', 600, weight: '20'),
      ],
    ]);
    expect(draft.assessments.length, 1);
    expect(draft.assessments.single.title, 'Exercise 2 (Individual)');
    expect(draft.assessments.single.source.assessmentWeight, 30);
    expect(draft.assessments.single.source.page, 2);
    expect(
      draft.assessments.single.source.excerpt,
      '1 Exercise 2 (Individual) 30 4',
    );
  });

  test(
    'Missing, ambiguous and invalid percentages never become hour values',
    () async {
      final draft = await _layoutDraft([
        [],
        [
          ..._header(),
          ..._row('1', 660),
          _word('10', 520, 660),
          _word('2', 550, 660),
          _word('1', 590, 660),
          ..._row('2', 640, weight: '150'),
          ..._row('3', 620, weight: '20'),
          _word('30', 460, 620),
          _word('TOTAL', 350, 600),
          ..._header(y: 570, percentage: false),
          ..._row('4', 540, weight: '25'),
        ],
      ]);
      // The fake reader also provides complete text rows. They must not be used
      // when positioned evidence cannot identify one valid percentage.
      expect(draft.assessments, isEmpty);
      expect(draft.warnings.any((w) => w.contains('No complete')), isTrue);
    },
  );

  test(
    'Layout keeps page references and skips duplicate source identities',
    () async {
      final draft = await _layoutDraft([
        [],
        [..._header(), ..._row('1', 660, weight: '35')],
        [..._row('1', 740, weight: '35'), ..._row('2', 700, weight: '65')],
      ]);
      expect(draft.assessments.map((a) => a.source.rowId), [
        'continuous-1',
        'continuous-2',
      ]);
      expect(draft.assessments.map((a) => a.source.page), [2, 3]);
      expect(
        draft.warnings.any((w) => w.contains('Repeated assessment row')),
        isTrue,
      );
    },
  );
  test('Supported template extracts explicit rows with separate identities and source pages', () async {
    final reader = FakeTextReader([coursePage, assessmentPage]);
    final service = ProformaImportService(reader: reader);
    final raw = Uint8List.fromList(
      utf8.encode('<html>prefix</html>%PDF-1.7 sample'),
    );
    final draft = await service.extract(raw, fileName: 'course.pdf');
    expect(draft.courseCode, 'DEQ3093');
    expect(draft.courseName, 'Kursus Contoh / Example Course');
    expect(draft.documentSession, 'Semester 1 Sesi 2026/2027');
    expect(draft.assessments.length, 5);
    expect(draft.assessments.map((a) => a.source.rowId).toSet().length, 5);
    expect(draft.assessments[1].title, draft.assessments[2].title);
    expect(draft.assessments.map((a) => a.source.assessmentWeight), [
      15,
      25,
      15,
      5,
      40,
    ]);
    expect(draft.assessments.every((a) => a.source.page == 2), isTrue);
    expect(draft.warnings.any((w) => w.contains('extra data')), isTrue);
    expect(utf8.decode(reader.received!), startsWith('%PDF-'));
    final clean = await service.extract(
      reader.received!,
      fileName: 'renamed.pdf',
    );
    expect(clean.courseSource.fingerprint, draft.courseSource.fingerprint);
  });

  test(
    'Invalid PDF, scanned text and other templates fail without guessed data',
    () async {
      final emptyReader = ProformaImportService(reader: FakeTextReader(['']));
      await expectLater(
        emptyReader.extract(Uint8List(0), fileName: 'empty.pdf'),
        throwsFormatException,
      );
      await expectLater(
        emptyReader.extract(
          Uint8List.fromList([1, 2, 3]),
          fileName: 'wrong.pdf',
        ),
        throwsFormatException,
      );
      final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7'));
      await expectLater(
        emptyReader.extract(bytes, fileName: 'scanned.pdf'),
        throwsFormatException,
      );
      await expectLater(
        ProformaImportService(reader: FakeTextReader(['Semester calendar']))
            .extract(bytes, fileName: 'calendar.pdf'),
        throwsFormatException,
      );
      final noRows = await ProformaImportService(
        reader: FakeTextReader([coursePage]),
      ).extract(bytes, fileName: 'course.pdf');
      expect(noRows.assessments, isEmpty);
      expect(
        noRows.warnings.any((w) => w.contains('No complete assessment')),
        isTrue,
      );
    },
  );
}

ProformaTextWord _word(String text, double x, double y) => ProformaTextWord(
  text: text,
  left: x,
  right: x + text.length * 5,
  top: y + 5,
  bottom: y - 5,
);

List<ProformaTextWord> _header({double y = 700, bool percentage = true}) => [
  _word('Continuous', 90, y),
  _word('Assessment', 160, y),
  if (percentage) ...[_word('Percentage', 400, y), _word('(%)', 470, y)],
];

List<ProformaTextWord> _row(String id, double y, {String? weight}) => [
  _word(id, 50, y),
  _word('Exercise', 90, y),
  _word('2', 140, y),
  _word('(Individual)', 160, y),
  if (weight != null) _word(weight, 430, y),
  _word('4', 650, y),
];

Future<ProformaDraft> _layoutDraft(List<List<ProformaTextWord>> words) {
  final reader = _LayoutReader(words);
  return ProformaImportService(reader: reader).extract(
    Uint8List.fromList(utf8.encode('%PDF-1.7 fixture')),
    fileName: 'layout.pdf',
  );
}

class _LayoutReader extends FakeTextReader implements ProformaLayoutReader {
  _LayoutReader(this.words)
    : super([coursePage, assessmentPage, if (words.length > 2) 'Continuation']);
  final List<List<ProformaTextWord>> words;
  @override
  Future<ProformaDocumentText> readLayout(Uint8List bytes) async =>
      ProformaDocumentText(pages: pages, words: words);
}
