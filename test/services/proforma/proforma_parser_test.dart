import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/services/proforma/proforma_import_service.dart';

import '../../support/proforma_fixtures.dart';

void main() {
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
