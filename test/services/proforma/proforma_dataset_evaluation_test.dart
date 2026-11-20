import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:planova/models/proforma.dart';
import 'package:planova/services/proforma/proforma_import_service.dart';

const _directory = 'research/evaluation/proforma_import';
const _referencePath = '$_directory/reference.json';

String _text(Object? value) =>
    value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  test(
    'Evaluate current Flutter extraction against local reviewed references',
    () async {
      final reference = jsonDecode(
        await File(_referencePath).readAsString(),
      ) as Map<String, dynamic>;
      expect(reference['schema_version'], 1);
      final datasetHashes = reference['dataset_sha256'] as Map<String, dynamic>;
      for (final entry in datasetHashes.entries) {
        final bytes = await File('research/datasets/${entry.key}')
            .readAsBytes();
        expect(
          sha256.convert(bytes).toString(),
          entry.value,
          reason: 'Dataset changed. Regenerate local references first.',
        );
      }
      final service = ProformaImportService(
        reader: PdfrxProformaTextReader(
          initialize: () =>
              pdfrxInitialize(tmpPath: '.dart_tool/proforma_inspection'),
        ),
      );
      final results = <Map<String, dynamic>>[];
      for (final document in reference['documents'] as List<dynamic>) {
        final expected = document as Map<String, dynamic>;
        final source = File(expected['source_file'] as String);
        final bytes = await source.readAsBytes();
        expect(
          sha256.convert(bytes).toString(),
          expected['source_sha256'],
          reason: 'Source PDF changed. Regenerate reviewed references first.',
        );
        ProformaDraft? draft;
        String? error;
        try {
          draft = await service.extract(
            bytes,
            fileName: source.uri.pathSegments.last,
          );
        } on FormatException catch (exception) {
          error = exception.message;
        }
        if (draft != null) {
          expect(
            draft.courseSource.fingerprint,
            expected['normalized_pdf_sha256'],
          );
        }
        final actualById = {
          for (final assessment in draft?.assessments ?? <AssessmentDraft>[])
            assessment.source.rowId: assessment,
        };
        expect(actualById.length, draft?.assessments.length ?? 0);
        final expectedRows = expected['assessments'] as List<dynamic>;
        final expectedIds = expectedRows
            .map((row) => (row as Map<String, dynamic>)['row_id'])
            .toSet();
        final rows = <Map<String, dynamic>>[];
        for (final value in expectedRows) {
          final row = value as Map<String, dynamic>;
          final actual = actualById[row['row_id']];
          final checks = {
            'name': actual != null && _text(actual.title) == _text(row['name']),
            'weight':
                actual != null &&
                actual.source.assessmentWeight == row['weight'],
            'page': actual != null && actual.source.page == row['page'],
          };
          rows.add({
            'row_id': row['row_id'],
            'found': actual != null,
            'checks': checks,
            'exact_match': checks.values.every((value) => value),
            'expected': row,
            'actual': actual == null
                ? null
                : {
                    'name': actual.title,
                    'weight': actual.source.assessmentWeight,
                    'page': actual.source.page,
                  },
          });
        }
        final courseChecks = {
          'code': draft != null && draft.courseCode == expected['course_code'],
          'name':
              draft != null &&
              _text(draft.courseName) == _text(expected['course_name']),
          'session':
              draft != null &&
              _text(draft.documentSession) ==
                  _text(expected['document_session']),
        };
        final extras = actualById.keys
            .where((id) => !expectedIds.contains(id))
            .toList();
        results.add({
          'document_id': expected['document_id'],
          'course_code': expected['course_code'],
          'source_file': expected['source_file'],
          'error': error,
          'course_checks': courseChecks,
          'actual_course': {
            'code': draft?.courseCode,
            'name': draft?.courseName,
            'session': draft?.documentSession,
          },
          'expected_assessments': rows.length,
          'extracted_assessments': actualById.length,
          'exact_assessments': rows
              .where((r) => r['exact_match'] == true)
              .length,
          'unexpected_row_ids': extras,
          'rows': rows,
          'warnings': draft?.warnings ?? [],
          'exact_document':
              error == null &&
              courseChecks.values.every((value) => value) &&
              rows.every((row) => row['exact_match'] == true) &&
              extras.isEmpty,
        });
      }
      final summary = {
        'documents': results.length,
        'exact_documents': results
            .where((r) => r['exact_document'] == true)
            .length,
        'expected_assessments': results.fold<int>(
          0,
          (sum, r) => sum + (r['expected_assessments'] as int),
        ),
        'extracted_assessments': results.fold<int>(
          0,
          (sum, r) => sum + (r['extracted_assessments'] as int),
        ),
        'exact_assessments': results.fold<int>(
          0,
          (sum, r) => sum + (r['exact_assessments'] as int),
        ),
      };
      final report = {
        'schema_version': 1,
        'implementation_sha256': {
          for (final path in [
            'lib/services/proforma/upsi_proforma_parser.dart',
            'lib/services/proforma/proforma_import_service.dart',
            'lib/services/proforma/upsi_assessment_layout.dart',
            'lib/models/proforma.dart',
          ])
            path: sha256.convert(await File(path).readAsBytes()).toString(),
        },
        'scope': reference['scope'],
        'metric': 'Exact assessment: source row identity, name, percentage, and PDF page all match. A passing report-generation test is not an accuracy threshold.',
        'reference_sha256': sha256
            .convert(await File(_referencePath).readAsBytes())
            .toString(),
        'dataset_sha256': datasetHashes,
        'summary': summary,
        'documents': results,
      };
      await File('$_directory/results.json').writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      );
      final markdown = StringBuffer()
        ..writeln('# Flutter proforma extraction evaluation')
        ..writeln()
        ..writeln(reference['scope'])
        ..writeln()
        ..writeln(
          'Exact courses: ${summary['exact_documents']}/${summary['documents']}.',
        )
        ..writeln(
          'Exact assessments: ${summary['exact_assessments']}/${summary['expected_assessments']}.',
        )
        ..writeln()
        ..writeln(
          'Exact means course code/name/session plus every assessment name, percentage, source row identity and PDF page match. No weekly-topic or workload extraction is evaluated.',
        )
        ..writeln()
        ..writeln(
          '| Course | Course fields | Extracted / expected | Exact assessments |',
        )
        ..writeln('| --- | --- | ---: | ---: |');
      for (final result in results) {
        final checks = result['course_checks'] as Map<String, bool>;
        markdown.writeln(
          '| ${result['course_code']} | ${checks.values.every((v) => v) ? 'Match' : 'Mismatch'} | ${result['extracted_assessments']} / ${result['expected_assessments']} | ${result['exact_assessments']} |',
        );
      }
      markdown
        ..writeln()
        ..writeln(
          'See results.json for missed rows, differences, and parser warnings. These are known local reference documents, not a held-out evaluation or proof of support for every UPSI format.',
        );
      await File('$_directory/RESULTS.md').writeAsString(markdown.toString());
      // This evaluates and records the current baseline, including failures.
      // Use the opt-in gate when testing a claimed exact-extraction milestone.
      if (const bool.fromEnvironment('PLANOVA_REQUIRE_EXACT_PROFORMA')) {
        expect(summary['exact_documents'], summary['documents']);
      }
    },
    skip: !File(_referencePath).existsSync()
        ? 'Run python tool/prepare_proforma_evaluation.py with local reviewed PDFs.'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
