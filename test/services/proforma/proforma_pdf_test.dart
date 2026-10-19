import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:planova/services/proforma/proforma_import_service.dart';

void main() {
  const path = 'research/proformas/Sem 7/Konfigurasi/profoma.pdf';
  test('Real DEQ3093 PDF produces course and five assessment drafts through PDFium', () async {
    final service = ProformaImportService(
      reader: PdfrxProformaTextReader(
        initialize: () =>
            pdfrxInitialize(tmpPath: '.dart_tool/proforma_inspection'),
      ),
    );
    final draft = await service.extract(
      await File(path).readAsBytes(),
      fileName: 'profoma.pdf',
    );
    expect(draft.courseCode, 'DEQ3093');
    expect(draft.courseName, contains('Software Configuration Management'));
    expect(draft.assessments.length, 5);
    expect(draft.assessments.map((a) => a.source.assessmentWeight), [
      15,
      25,
      15,
      5,
      40,
    ]);
    expect(draft.assessments.every((a) => a.source.page == 9), isTrue);
  }, skip: !File(path).existsSync());
}
