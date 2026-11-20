import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:planova/services/proforma/proforma_import_service.dart';
import 'package:planova/services/proforma/upsi_weekly_layout.dart';

const directory = 'research/evaluation/proforma_import';

void main() {
  test(
    'Evaluate weekly source extraction against reviewed local references',
    () async {
      final reference = jsonDecode(
        await File('$directory/reference.json').readAsString(),
      ) as Map<String, dynamic>;
      for (final entry
          in (reference['dataset_sha256'] as Map<String, dynamic>).entries) {
        expect(
          sha256
              .convert(
                await File('research/datasets/${entry.key}').readAsBytes(),
              )
              .toString(),
          entry.value,
        );
      }
      if (reference['source_review_path'] != null) {
        expect(
          sha256
              .convert(
                await File(reference['source_review_path'] as String)
                    .readAsBytes(),
              )
              .toString(),
          reference['source_review_sha256'],
        );
      }
      final service = ProformaImportService(
        reader: PdfrxProformaTextReader(
          initialize: () =>
              pdfrxInitialize(tmpPath: '.dart_tool/proforma_inspection'),
        ),
      );
      final results = <Map<String, dynamic>>[];
      var expectedCount = 0;
      var actualCount = 0;
      var exactCount = 0;
      for (final document in reference['documents'] as List<dynamic>) {
        final bytes = await File(document['source_file'] as String)
            .readAsBytes();
        expect(sha256.convert(bytes).toString(), document['source_sha256']);
        final draft = await service.extract(
          bytes,
          fileName: document['source_file'] as String,
        );
        final expected = document['weekly'] as List<dynamic>;
        final actual = draft.weeklyLearning;
        final differences = <Map<String, dynamic>>[];
        var exact = 0;
        for (var i = 0; i < expected.length; i++) {
          if (i >= actual.length) {
            differences.add({'row': i, 'missing': true});
            continue;
          }
          final row = actual[i];
          final e = expected[i];
          final a = {
            'week_start': row.weekStart,
            'week_end': row.weekEnd,
            'topic': UpsiWeeklyLayout.normalizeTopic(row.topic),
            'page': row.source.page,
            'source_hours': [
              row.guidedNf2fHours,
              row.independentNf2fHours,
              ...row.onlineHours,
              row.totalSltHours,
            ],
          };
          final expectedRow = {
            'week_start': e['week_start'],
            'week_end': e['week_end'],
            'topic': UpsiWeeklyLayout.normalizeTopic(e['topic'] as String),
            'page': e['page'],
            'source_hours': e['source_hours'],
          };
          if (jsonEncode(a) == jsonEncode(expectedRow)) {
            exact++;
          } else {
            differences.add({
              'row': i,
              'id': e['learning_id'],
              'expected': expectedRow,
              'actual': a,
            });
          }
        }
        expectedCount += expected.length;
        actualCount += actual.length;
        exactCount += exact;
        results.add({
          'course': document['course_code'],
          'expected': expected.length,
          'actual': actual.length,
          'exact': exact,
          'differences': differences,
          'warnings': draft.warnings,
        });
      }
      final report = {
        'reference_sha256': sha256
            .convert(await File('$directory/reference.json').readAsBytes())
            .toString(),
        'implementation_sha256': {
          for (final path in [
            'lib/services/proforma/upsi_weekly_layout.dart',
            'lib/services/proforma/upsi_proforma_parser.dart',
            'lib/services/proforma/proforma_import_service.dart',
            'lib/models/proforma.dart',
          ])
            path: sha256.convert(await File(path).readAsBytes()).toString(),
        },
        'expected': expectedCount,
        'actual': actualCount,
        'exact': exactCount,
        'documents': results,
        'scope': 'Printed weekly values and complete topics, with whitespace, ligature, fullwidth ASCII, punctuation-spacing and line-break hyphen normalization. Document-specific corrections in reviewed CSVs are compared to recorded printed evidence; upload does not silently apply them.',
      };
      await File('$directory/weekly_results.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      final markdown =
          StringBuffer('# Weekly proforma extraction evaluation\n\n')
            ..writeln(
              'Exact source rows: $exactCount/$expectedCount; extracted: $actualCount.\n',
            )
            ..writeln(
              '| Course | Expected | Extracted | Exact |\n| --- | ---: | ---: | ---: |',
            );
      for (final r in results) {
        markdown.writeln(
          '| ${r['course']} | ${r['expected']} | ${r['actual']} | ${r['exact']} |',
        );
      }
      markdown.writeln('\n${report['scope']}');
      await File('$directory/WEEKLY_RESULTS.md')
          .writeAsString(markdown.toString());
      if (const bool.fromEnvironment('PLANOVA_REQUIRE_EXACT_WEEKLY')) {
        expect(actualCount, expectedCount);
        expect(exactCount, expectedCount);
      }
    },
    skip: !File('$directory/reference.json').existsSync(),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
